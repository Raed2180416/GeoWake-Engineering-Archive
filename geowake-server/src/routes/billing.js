const express = require('express');
const { verifyPrepaidSubscription } = require('../services/playBillingVerifier');

const router = express.Router();

const PASS_PRODUCTS = new Set([
  'geowake_pro_daily',
  'geowake_pro_weekly',
  'geowake_pro_monthly',
  'geowake_pro_yearly'
]);

router.post('/verify', async (req, res) => {
  const productId = typeof req.body?.productId === 'string'
    ? req.body.productId.trim()
    : '';
  const purchaseToken = typeof req.body?.purchaseToken === 'string'
    ? req.body.purchaseToken.trim()
    : '';

  if (!PASS_PRODUCTS.has(productId) || purchaseToken.length < 16 || purchaseToken.length > 4096) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Play purchase payload'
    });
  }

  try {
    const result = await verifyPrepaidSubscription({ productId, purchaseToken });
    if (!result.verified) {
      return res.status(403).json({
        success: false,
        verified: false,
        error: 'Purchase is not an active entitlement'
      });
    }
    return res.json({ success: true, ...result });
  } catch (error) {
    if (error?.code === 'PLAY_NOT_CONFIGURED') {
      return res.status(503).json({
        success: false,
        error: 'Purchase verification is temporarily unavailable'
      });
    }
    // Never return Google/service-account details or the purchase token.
    console.error('Play purchase verification failed:', error?.message || 'unknown');
    return res.status(502).json({
      success: false,
      error: 'Could not verify purchase with Google Play'
    });
  }
});

module.exports = router;
