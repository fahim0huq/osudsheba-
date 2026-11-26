const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const admin = require('firebase-admin');

// Load environment variables
dotenv.config();

// Initialize Firebase Admin (uses project ID from environment or fallback)
const projectId = process.env.FIREBASE_PROJECT_ID || 'osudsheba-7b88a';
admin.initializeApp({
  projectId: projectId
});
console.log(`Firebase Admin SDK initialized for project: ${projectId}`);

const subscriptionRoutes = require('./routes/subscription.routes');
const { handleAppsProWebhook } = require('./webhooks/appspro.webhook');
const { webSubscriptionRouter } = require('./routes/web-subscription.routes');
const { createFamilyRouter } = require('./routes/family.routes');

const app = express();
const port = process.env.PORT || 3000;

// Render puts a proxy in front of the server: trust it, so req.ip is the caller's address
// rather than the proxy's (TRUST_PROXY_HOPS changes how many proxies are trusted).
app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS) >= 0 && process.env.TRUST_PROXY_HOPS !== undefined
  ? Number(process.env.TRUST_PROXY_HOPS)
  : 1);

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
app.use('/family', createFamilyRouter());

// Prescription scanning now runs on the phone (ML Kit OCR + bundled medicine list), so
// this server no longer receives prescription photos or calls a paid AI service.

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Error:', err);
  
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

const { AppsProService } = require('./services/appspro.service');

app.listen(port, '0.0.0.0', async () => {
  console.log(`OsudSheba Prescription Analysis Backend listening at http://0.0.0.0:${port}`);
  
  // Safe runtime startup diagnostics (never exposes secrets)
  AppsProService.logStartupDiagnostics();
  
  // Self-test AppsPro connectivity in background
  try {
    await AppsProService.getAppInfo();
    await AppsProService.testProtectedSubscribers();
  } catch (diagErr) {
    console.warn('[AppsPro Startup] Connectivity test warning:', diagErr.message);
  }
});
