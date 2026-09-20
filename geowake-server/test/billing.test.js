jest.mock('../src/services/playBillingVerifier', () => ({
  verifyPrepaidSubscription: jest.fn()
}));

const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../src/server');
const config = require('../src/config/config');
const { verifyPrepaidSubscription } = require('../src/services/playBillingVerifier');

function token() {
  return jwt.sign({ bundleId: config.appBundleId }, config.jwtSecret, {
    expiresIn: '5m',
    jwtid: 'billing-test-device'
  });
}

describe('POST /api/billing/verify', () => {
  beforeEach(() => jest.clearAllMocks());

  test('requires device authentication', async () => {
    const response = await request(app)
      .post('/api/billing/verify')
      .send({ productId: 'geowake_pro_monthly', purchaseToken: 'x'.repeat(32) });
    expect(response.status).toBe(401);
    expect(verifyPrepaidSubscription).not.toHaveBeenCalled();
  });

  test('rejects unknown products before contacting Google', async () => {
    const response = await request(app)
      .post('/api/billing/verify')
      .set('Authorization', `Bearer ${token()}`)
      .send({ productId: 'attacker_product', purchaseToken: 'x'.repeat(32) });
    expect(response.status).toBe(400);
    expect(verifyPrepaidSubscription).not.toHaveBeenCalled();
  });

  test('returns only an active Google-verified expiry', async () => {
    const expiry = Date.now() + 30 * 24 * 60 * 60 * 1000;
    verifyPrepaidSubscription.mockResolvedValue({
      verified: true,
      productId: 'geowake_pro_monthly',
      expiryTimeMillis: expiry,
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING'
    });
    const response = await request(app)
      .post('/api/billing/verify')
      .set('Authorization', `Bearer ${token()}`)
      .send({ productId: 'geowake_pro_monthly', purchaseToken: 'p'.repeat(32) });
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      success: true,
      verified: true,
      productId: 'geowake_pro_monthly',
      expiryTimeMillis: expiry
    });
  });

  test('does not grant an inactive or expired purchase', async () => {
    verifyPrepaidSubscription.mockResolvedValue({
      verified: false,
      productId: 'geowake_pro_daily',
      expiryTimeMillis: Date.now() - 1,
      subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED'
    });
    const response = await request(app)
      .post('/api/billing/verify')
      .set('Authorization', `Bearer ${token()}`)
      .send({ productId: 'geowake_pro_daily', purchaseToken: 'p'.repeat(32) });
    expect(response.status).toBe(403);
    expect(response.body.verified).toBe(false);
  });
});
