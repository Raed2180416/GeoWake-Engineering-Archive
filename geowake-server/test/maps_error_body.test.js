/**
 * Maps proxy — Google in-body error-status handling (BACKLOG #24)
 *
 * Google's Maps web-service APIs return HTTP 200 even when the request failed,
 * signalling the real outcome via an in-body `status` field
 * (OVER_QUERY_LIMIT / REQUEST_DENIED / INVALID_REQUEST / ...). axios does not
 * throw on those, so the proxy must inspect the body and return a real HTTP
 * failure. Google response content is never server-cached.
 *
 * These tests mock axios (no network) and drive the real controller + real
 * controller to prove:
 *   - a 200 OVER_QUERY_LIMIT body yields HTTP 429
 *   - a 200 REQUEST_DENIED body yields HTTP 502
 *   - a 200 OK body yields HTTP 200
 *   - identical OK requests both reach upstream (no prohibited content cache)
 */

// Config validates env at require-time (process.exit(1) if missing), so these
// must be set before any src/* module is required.
process.env.GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || 'test-maps-key';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-jwt-secret-at-least-32-characters-long';
process.env.APP_BUNDLE_ID = process.env.APP_BUNDLE_ID || 'com.geowake.app';

jest.mock('axios');
const axios = require('axios');

const { getDirections } = require('../src/controllers/mapsController');

// Minimal req/res doubles. `res.json`/`res.status().json()` both terminate the
// request; we resolve a promise on the first terminal call so tests can await
// the fire-and-forget async proxy the handler kicks off.
function makeReqRes(body) {
  const res = {
    statusCode: 200,
    body: undefined,
    _resolve: null,
    done: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      if (this._resolve) this._resolve();
      return this;
    },
  };
  res.done = new Promise((resolve) => {
    res._resolve = resolve;
  });
  return { req: { body }, res };
}

async function callDirections(body) {
  const { req, res } = makeReqRes(body);
  getDirections(req, res); // handler does not return the inner async promise
  await res.done;
  return res;
}

describe('Maps proxy — Google in-body error statuses (BACKLOG #24)', () => {
  beforeEach(() => {
    axios.get.mockReset();
  });

  test('200 OVER_QUERY_LIMIT returns 429', async () => {
    axios.get.mockResolvedValue({ status: 200, data: { status: 'OVER_QUERY_LIMIT' } });

    const params = { origin: 'A', destination: 'B', mode: 'driving' };
    const res = await callDirections(params);

    expect(res.statusCode).toBe(429);
    expect(res.body.success).toBe(false);
    expect(res.body.status).toBe('OVER_QUERY_LIMIT');
  });

  test('200 REQUEST_DENIED returns 502', async () => {
    axios.get.mockResolvedValue({
      status: 200,
      data: { status: 'REQUEST_DENIED', error_message: 'API key invalid' },
    });

    const params = { origin: 'C', destination: 'D', mode: 'driving' };
    const res = await callDirections(params);

    expect(res.statusCode).toBe(502);
    expect(res.body.success).toBe(false);
    expect(res.body.status).toBe('REQUEST_DENIED');
  });

  test('200 OK returns 200', async () => {
    const okBody = { status: 'OK', routes: [{ summary: 'Main St' }] };
    axios.get.mockResolvedValue({ status: 200, data: okBody });

    const params = { origin: 'E', destination: 'F', mode: 'driving' };
    const res = await callDirections(params);

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual(okBody);
  });

  test('identical OK requests are not server-cached', async () => {
    const okBody = { status: 'OK', routes: [{ summary: 'Second St' }] };
    axios.get.mockResolvedValue({ status: 200, data: okBody });

    const params = { origin: 'G', destination: 'H', mode: 'driving' };
    await callDirections(params);
    await callDirections(params);

    expect(axios.get).toHaveBeenCalledTimes(2);
  });
});
