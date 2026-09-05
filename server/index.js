const express = require('express');
const cors = require('cors');
const multer = require('multer');
const dotenv = require('dotenv');
const Replicate = require('replicate');
const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');
const rateLimit = require('express-rate-limit');

// Load environment variables
dotenv.config();

// Initialize Firebase Admin (uses project ID from environment or fallback)
const projectId = process.env.FIREBASE_PROJECT_ID || 'osudsheba-7b88a';
admin.initializeApp({
  projectId: projectId
});
console.log(`Firebase Admin SDK initialized for project: ${projectId}`);

// Firebase ID Token verification middleware
async function authenticateFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Access denied. No Firebase ID token provided in the Authorization header.'
    });
  }

  const token = authHeader.split('Bearer ')[1];
  try {
    // Allow mock authentication in development/testing mode ONLY (never in production)
    if (process.env.NODE_ENV !== 'production' && process.env.ALLOW_MOCK_AUTH === 'true' && token.startsWith('mock_token_for_')) {
      const mockUid = token.replace('mock_token_for_', '');
      req.user = { uid: mockUid, email: `${mockUid}@example.com` };
      console.log(`Authenticated request using Mock Token for user: ${mockUid}`);
      return next();
    }

    const decodedToken = await getAuth().verifyIdToken(token);
    req.user = decodedToken; // contains uid, email, etc.
    console.log(`Authenticated request from user: ${decodedToken.uid}`);
    next();
  } catch (error) {
    console.error('Firebase ID token verification failed:', error.message);
    return res.status(401).json({
      success: false,
      error: 'Access denied. Invalid or expired Firebase ID token.'
    });
  }
}

const subscriptionRoutes = require('./routes/subscription.routes');
const { requireSubscription } = require('./middleware/requireSubscription');
const { handleAppsProWebhook } = require('./webhooks/appspro.webhook');
const { webSubscriptionRouter } = require('./routes/web-subscription.routes');

const app = express();
const port = process.env.PORT || 3000;

// Enable CORS with origin restrictions in production
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',') 
  : ['http://localhost:3000', 'http://localhost:5000'];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like native mobile apps, curl, etc.)
    if (!origin) return callback(null, true);
    if (process.env.NODE_ENV !== 'production' || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error('CORS Policy: Origin not allowed.'), false);
  }
}));

// AppsPro Webhook Route: MUST use express.raw({ type: 'application/json' }) BEFORE express.json()
// to preserve raw request bytes for HMAC-SHA256 signature and SHA256 body hash verification
app.post('/webhooks/appspro', express.raw({ type: 'application/json' }), handleAppsProWebhook);

app.use(express.json());

// Mount subscription routes and SDK proxy aliases
app.use('/subscription', subscriptionRoutes);
app.use('/appspro', subscriptionRoutes);
app.use('/web-subscription', webSubscriptionRouter);

// Enforce per-user rate limiting specifically on the expensive prescription-analysis endpoint
const prescriptionAnalysisLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each user (or IP) to 10 requests per window
  keyGenerator: (req) => req.user ? req.user.uid : req.ip,
  validate: false,
  message: {
    success: false,
    error: 'Too many prescription analysis requests. Please try again after 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Initialize Replicate API client
const replicateToken = process.env.REPLICATE_API_TOKEN;
if (!replicateToken) {
  console.warn('NOTICE: REPLICATE_API_TOKEN is not currently defined. Set REPLICATE_API_TOKEN in environment variables for live analysis.');
}

const replicate = new Replicate({
  auth: replicateToken,
});

// Setup multer in memory storage with limits
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif'
    ];
    if (allowedMimeTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Invalid image type: ${file.mimetype}. Only JPEG, PNG, WEBP, and HEIC are supported.`), false);
    }
  }
});

// Prescription Analysis Endpoint (Premium Protected)
app.post('/analyze-prescription', authenticateFirebaseToken, requireSubscription, prescriptionAnalysisLimiter, upload.single('image'), async (req, res) => {
  try {
    // 1. Check if file is uploaded
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No image file uploaded.'
      });
    }

    // 2. Validate Replicate token configuration
    if (!process.env.REPLICATE_API_TOKEN) {
      console.error('Prescription analysis failed: REPLICATE_API_TOKEN is not configured.');
      return res.status(500).json({
        success: false,
        error: 'Prescription analysis service is not configured with REPLICATE_API_TOKEN.'
      });
    }

    console.log(`Received prescription image: ${req.file.originalname} (${req.file.mimetype}, ${req.file.size} bytes)`);

    // 3. Format the image buffer as Base64 Data URI for Replicate input
    const dataUri = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;

    // 4. Setup Replicate Model config (defaults to google/gemini-2.5-flash)
    const configuredModel = process.env.REPLICATE_MODEL || 'google/gemini-2.5-flash';
    console.log(`Calling Replicate model: ${configuredModel}`);

    // 5. Structured extraction prompt with strict pharmacology & Bengali handwriting awareness
    const systemPrompt = `You are a pharmacology-aware AI extractor for Bangladeshi medical prescriptions.
Analyze the provided prescription image and extract the patient details, doctor details, a complete transcript of text, and all prescribed medicines with structural precision.

Rules:
1. Extract only what is written and visually supported in the image. Never invent, guess, or extrapolate.
2. If text is unclear, unreadable, or missing, return null or empty values as specified and mark the item as uncertain by setting a low confidence (e.g. < 0.6).
3. If the medicine name is unreadable or unclear, write "unclear" for the name.
4. Support handwritten prescriptions, Bengali (Bangla), English, and mixed-script prescriptions.
5. Support common Bangladeshi prescription shorthand:
   - "1+0+1" or "১+০+১" means Morning (08:00 AM) and Night (08:00 PM).
   - "০+১+০" means Afternoon (02:00 PM).
   - "১+১+১" means Morning (08:00 AM), Afternoon (02:00 PM), and Night (08:00 PM).
   - "OD" / "once daily" maps to Night (08:00 PM) or Morning (08:00 AM).
   - "BD" / "twice daily" maps to Morning (08:00 AM) and Night (08:00 PM).
   - "TDS" / "three times daily" maps to Morning (08:00 AM), Afternoon (02:00 PM), and Night (08:00 PM).
   - "খাবারের আগে" maps to Before Meal.
   - "খাবারের পরে" maps to After Meal.
6. Allowed clock values for the "times" array are strictly: "08:00 AM", "02:00 PM", "08:00 PM".
7. The confidence rating must be between 0.0 (unreadable/pure guess) and 1.0 (perfectly clear). If you are uncertain about a medicine name or dosage, use a confidence score below 0.8.
8. Never diagnose the patient. Never recommend additional medicines. You are an information extraction system only.

Return a JSON object conforming exactly to this schema:
{
  "patientName": "string or null",
  "doctorName": "string or null",
  "date": "string or null (e.g. YYYY-MM-DD)",
  "rawText": "A clean, markdown-formatted full transcript of all textual content readable from the prescription image.",
  "medicines": [
    {
      "name": "string (brand or name, capitalized. Use 'unclear' if not legible)",
      "genericName": "string or null (if visible/present)",
      "strength": "string or null (e.g. '500mg', '20mg', '100ml')",
      "form": "one of: 'tablet', 'capsule', 'syrup', 'injection'",
      "dose": "string or null (e.g. '1 Tablet', '1 Capsule', '5ml')",
      "frequency": "string or null (e.g. '1+0+1', 'once daily')",
      "times": ["string (strictly selected from: '08:00 AM', '02:00 PM', '08:00 PM')"],
      "durationDays": "number or null (use null if not specified)",
      "mealRelation": "one of: 'Before Meal', 'After Meal', 'With Meal', 'None'",
      "instruction": "string or null (additional instructions like 'with water')",
      "confidence": "number (0.0 to 1.0)"
    }
  ]
}`;

    const userPrompt = `${systemPrompt}\n\nExtract all prescription information from the attached image. Respond ONLY with valid JSON conforming to the schema above.`;

    // 6. Call Replicate API with google/gemini-2.5-flash
    let output;
    try {
      output = await replicate.run(configuredModel, {
        input: {
          prompt: userPrompt,
          system_instruction: systemPrompt,
          images: [dataUri],
          temperature: 0.1,
        }
      });
    } catch (replicateErr) {
      console.error('Replicate API execution error:', replicateErr.message);
      return res.status(502).json({
        success: false,
        error: 'Failed to communicate with Replicate Gemini model. Please check token or retry.'
      });
    }

    let responseText = '';
    if (Array.isArray(output)) {
      responseText = output.join('');
    } else if (typeof output === 'string') {
      responseText = output;
    } else if (output && typeof output === 'object') {
      responseText = JSON.stringify(output);
    } else {
      throw new Error('Received unexpected or empty response from Replicate.');
    }

    if (!responseText) {
      throw new Error('Received empty response text from Replicate Gemini API.');
    }

    // 7. Extract and parse JSON safely
    let jsonStr = responseText.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }
    const firstBrace = jsonStr.indexOf('{');
    const lastBrace = jsonStr.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1) {
      jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
    }

    let parsedResult;
    try {
      parsedResult = JSON.parse(jsonStr);
    } catch (parseErr) {
      console.error('Failed to parse Replicate Gemini response as JSON. Raw response:', responseText);
      return res.status(500).json({
        success: false,
        error: 'The AI model generated an invalid data format.'
      });
    }

    // 8. Perform normalization, field mapping, and build warnings
    const warnings = [];
    const medicines = [];

    if (!parsedResult.medicines || !Array.isArray(parsedResult.medicines)) {
      warnings.push('No medicines array found in AI response.');
      parsedResult.medicines = [];
    }

    for (const med of parsedResult.medicines) {
      // Validate name
      const name = med.name ? String(med.name).trim() : 'unclear';
      
      // Validate form
      let form = 'tablet';
      const rawForm = String(med.form || '').toLowerCase();
      if (['tablet', 'capsule', 'syrup', 'injection'].includes(rawForm)) {
        form = rawForm;
      } else {
        warnings.push(`Invalid medicine form "${med.form}" corrected to "tablet" for medicine: ${name}`);
      }

      // Validate meal relation
      let mealRelation = 'None';
      const rawMeal = String(med.mealRelation || '');
      if (['Before Meal', 'After Meal', 'With Meal', 'None'].includes(rawMeal)) {
        mealRelation = rawMeal;
      } else {
        mealRelation = 'None';
      }

      // Validate times
      const times = [];
      if (Array.isArray(med.times)) {
        for (const t of med.times) {
          const cleanT = String(t).trim();
          if (['08:00 AM', '02:00 PM', '08:00 PM'].includes(cleanT)) {
            times.push(cleanT);
          }
        }
      }
      if (times.length === 0) {
        times.push('08:00 AM'); // Default fallback time
        warnings.push(`Missing or invalid times for medicine "${name}". Defaulted to "08:00 AM".`);
      }

      // Validate confidence
      let confidence = parseFloat(med.confidence);
      if (isNaN(confidence) || confidence < 0.0 || confidence > 1.0) {
        confidence = 0.5; // default moderate uncertainty
      }

      medicines.push({
        name,
        genericName: med.genericName ? String(med.genericName) : null,
        strength: med.strength ? String(med.strength) : null,
        form,
        dose: med.dose ? String(med.dose) : '1 Tablet',
        frequency: med.frequency ? String(med.frequency) : null,
        times,
        durationDays: typeof med.durationDays === 'number' ? med.durationDays : null,
        mealRelation,
        instruction: med.instruction ? String(med.instruction) : null,
        confidence
      });
    }

    // 9. Return response (compatible with both prescription.medicines and top-level medicines)
    return res.json({
      success: true,
      prescription: {
        patientName: parsedResult.patientName ? String(parsedResult.patientName) : null,
        doctorName: parsedResult.doctorName ? String(parsedResult.doctorName) : null,
        date: parsedResult.date ? String(parsedResult.date) : null,
        rawText: parsedResult.rawText ? String(parsedResult.rawText) : '',
        medicines
      },
      medicines,
      warnings
    });

  } catch (error) {
    console.error('Error during prescription analysis:', error);
    return res.status(500).json({
      success: false,
      error: 'An internal error occurred during prescription analysis.'
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    engine: 'replicate',
    model: process.env.REPLICATE_MODEL || 'google/gemini-2.5-flash',
    hasToken: Boolean(process.env.REPLICATE_API_TOKEN)
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Error:', err);
  
  // Handle Multer errors (file too large, etc.)
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File size limit exceeded. Maximum allowed size is 5MB.'
      });
    }
    return res.status(400).json({
      success: false,
      error: err.message
    });
  }
  
  // Handle custom validation/mime-type errors from file filter
  if (err.message && err.message.startsWith('Invalid image type')) {
    return res.status(400).json({
      success: false,
      error: err.message
    });
  }

  // Handle CORS policy errors
  if (err.message && err.message.startsWith('CORS Policy')) {
    return res.status(403).json({
      success: false,
      error: err.message
    });
  }
  
  // Sanitize all internal server errors in production
  res.status(500).json({
    success: false,
    error: 'Prescription analysis temporarily unavailable. Please try again later.'
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`OsudSheba Prescription Analysis Backend listening at http://0.0.0.0:${port}`);
});
