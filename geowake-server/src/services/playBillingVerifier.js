const { GoogleAuth } = require('google-auth-library');
const config = require('../config/config');

const PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const ACTIVE_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  // A canceled prepaid plan remains usable until its paid expiry.
  'SUBSCRIPTION_STATE_CANCELED'
]);

let clientPromise;

function credentials() {
  if (!config.googlePlayServiceAccountJson) {
    const error = new Error('Google Play verification is not configured');
    error.code = 'PLAY_NOT_CONFIGURED';
    throw error;
  }
  try {
    return JSON.parse(config.googlePlayServiceAccountJson);
  } catch (_) {
    const error = new Error('Google Play service-account JSON is invalid');
    error.code = 'PLAY_NOT_CONFIGURED';
    throw error;
  }
}

async function client() {
  clientPromise ??= new GoogleAuth({
    credentials: credentials(),
    scopes: [PLAY_SCOPE]
  }).getClient();
  return clientPromise;
}

async function verifyPrepaidSubscription({ productId, purchaseToken }) {
  const authClient = await client();
  const packageName = encodeURIComponent(config.googlePlayPackageName);
  const token = encodeURIComponent(purchaseToken);
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptionsv2/tokens/${token}`;
  const response = await authClient.request({ url, method: 'GET' });
  const data = response.data || {};
  const lines = Array.isArray(data.lineItems) ? data.lineItems : [];
  const matching = lines.filter((line) => line.productId === productId);
  const expiryMs = matching.reduce((latest, line) => {
    const parsed = Date.parse(line.expiryTime || '');
    return Number.isFinite(parsed) ? Math.max(latest, parsed) : latest;
  }, 0);
  const active = ACTIVE_STATES.has(data.subscriptionState) && expiryMs > Date.now();

  return {
    verified: active,
    productId,
    expiryTimeMillis: expiryMs,
    subscriptionState: data.subscriptionState || 'SUBSCRIPTION_STATE_UNSPECIFIED',
    acknowledgementState: data.acknowledgementState || 'ACKNOWLEDGEMENT_STATE_UNSPECIFIED'
  };
}

module.exports = { verifyPrepaidSubscription };
