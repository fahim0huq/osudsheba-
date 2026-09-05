/**
 * Firebase Authentication Middleware
 * Validates the Firebase ID token in the Authorization header.
 * Attaches decoded user identity to req.user.
 */

const { getAuth } = require('firebase-admin/auth');

async function authenticateFirebaseToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'AUTH_REQUIRED',
      message: 'Access denied. No Firebase ID token provided in Authorization header.'
    });
  }

  const token = authHeader.split('Bearer ')[1].trim();

  try {
    // Allow mock authentication for local development/testing ONLY
    if (process.env.NODE_ENV !== 'production' && process.env.ALLOW_MOCK_AUTH === 'true' && token.startsWith('mock_token_for_')) {
      const mockUid = token.replace('mock_token_for_', '');
      req.user = { uid: mockUid, email: `${mockUid}@example.com` };
      return next();
    }

    const decodedToken = await getAuth().verifyIdToken(token);
    req.user = decodedToken; // Guaranteed authoritative req.user.uid
    next();
  } catch (error) {
    console.error('Firebase ID token verification failed:', error.message);
    return res.status(401).json({
      success: false,
      error: 'AUTH_INVALID',
      message: 'Access denied. Invalid or expired Firebase ID token.'
    });
  }
}

module.exports = {
  authenticateFirebaseToken,
};
