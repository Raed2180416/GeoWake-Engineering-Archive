const request = require('supertest');
const app = require('../src/server');

describe('Public legal pages', () => {
  test('Terms match the authoritative prepaid pass ladder', async () => {
    const response = await request(app).get('/legal/terms').expect(200);

    expect(response.text).toContain('₹7');
    expect(response.text).toContain('₹35');
    expect(response.text).toContain('₹99');
    expect(response.text).toContain('₹899');
    expect(response.text).toMatch(/do\s+not auto-renew/);
    expect(response.text).toMatch(/lifetime\s+purchase is not part/);
    expect(response.text).not.toContain('Pro is a one-time purchase');
  });

  test('Privacy copy matches tracking banners and composer-based Guardian', async () => {
    const response = await request(app).get('/legal/privacy').expect(200);

    expect(response.text).toContain('banner may appear below the map');
    expect(response.text).toContain('You choose whether to press Send');
    expect(response.text).toContain('never placed over the wake-alarm screen');
    expect(response.text).not.toContain(
      'Ads are never shown on the tracking or alarm screen',
    );
  });
});
