#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');

// Provider-neutral, read-only parity probe for GeoWake's existing /api/maps
// boundary. It deliberately keeps the current Google-compatible response
// contract so an Oracle-hosted replacement can be shadow-tested without
// changing the mobile app first. Raw provider content and bearer tokens are
// never printed or written to disk; only schema, topology, and latency summaries
// leave the process.

const baseUrl = process.env.PROBE_API_BASE_URL;
const bundleId = process.env.PROBE_BUNDLE_ID || 'com.geowake.app';

if (!baseUrl) {
  console.error('Set PROBE_API_BASE_URL to the GeoWake /api base URL.');
  process.exit(2);
}

const cityCases = [
  {
    city: 'bengaluru',
    query: 'Indiranagar Metro Bengaluru',
    origin: '12.9783325,77.6386612',
    destination: '12.9757079,77.5728757',
  },
  {
    city: 'mumbai',
    query: 'Andheri Metro Mumbai',
    origin: '19.0867792,72.9080649',
    destination: '19.120561,72.8487279',
  },
  {
    city: 'chennai',
    query: 'Chennai Central Metro',
    origin: '12.9808255,80.1642095',
    destination: '13.0851617,80.275155',
  },
  {
    city: 'hyderabad',
    query: 'Ameerpet Metro Hyderabad',
    origin: '17.4964542,78.3729359',
    destination: '17.4356865,78.4445922',
  },
  {
    city: 'kochi',
    query: 'Maharajas College Metro Kochi',
    origin: '10.1099872,76.3495149',
    destination: '9.9732357,76.2850733',
  },
];

function percentile(values, fraction) {
  if (!values.length) return null;
  const ordered = [...values].sort((a, b) => a - b);
  return ordered[Math.min(ordered.length - 1, Math.ceil(fraction * ordered.length) - 1)];
}

async function timedFetch(path, options) {
  const started = performance.now();
  const response = await fetch(`${baseUrl.replace(/\/$/, '')}${path}`, options);
  const elapsedMs = Math.round(performance.now() - started);
  let body;
  try {
    body = await response.json();
  } catch (_) {
    body = null;
  }
  return { statusCode: response.status, body, elapsedMs };
}

function locationOk(location) {
  return location && Number.isFinite(Number(location.lat)) && Number.isFinite(Number(location.lng));
}

function auditDirections(body, { requireTransit }) {
  const errors = [];
  if (!body || body.status !== 'OK') errors.push(`status=${body && body.status}`);
  const routes = body && Array.isArray(body.routes) ? body.routes : [];
  if (!routes.length) errors.push('routes.empty');
  const route = routes[0] || {};
  if (!route.overview_polyline || typeof route.overview_polyline.points !== 'string' || !route.overview_polyline.points) {
    errors.push('overview_polyline.points');
  }
  const legs = Array.isArray(route.legs) ? route.legs : [];
  if (!legs.length) errors.push('legs.empty');

  let durationSeconds = 0;
  let distanceMeters = 0;
  let transitSteps = 0;
  let totalSteps = 0;
  const modes = new Set();
  for (const leg of legs) {
    durationSeconds += Number(leg && leg.duration && leg.duration.value) || 0;
    distanceMeters += Number(leg && leg.distance && leg.distance.value) || 0;
    const steps = leg && Array.isArray(leg.steps) ? leg.steps : [];
    if (!steps.length) errors.push('leg.steps.empty');
    for (const step of steps) {
      totalSteps += 1;
      const mode = String(step.travel_mode || '').toUpperCase();
      if (!mode) errors.push('step.travel_mode');
      modes.add(mode);
      if (!step.polyline || typeof step.polyline.points !== 'string' || !step.polyline.points) {
        errors.push('step.polyline.points');
      }
      if (mode !== 'TRANSIT') continue;
      transitSteps += 1;
      const td = step.transit_details || {};
      if (!Number.isInteger(td.num_stops) || td.num_stops < 0) errors.push('transit.num_stops');
      if (!td.line || !(td.line.short_name || td.line.name)) errors.push('transit.line.name');
      if (!td.line || !td.line.vehicle || !td.line.vehicle.type) errors.push('transit.line.vehicle.type');
      for (const key of ['departure_stop', 'arrival_stop']) {
        const stop = td[key];
        if (!stop || !stop.name || !locationOk(stop.location)) errors.push(`transit.${key}`);
      }
    }
  }
  if (durationSeconds <= 0) errors.push('duration.nonpositive');
  if (distanceMeters <= 0) errors.push('distance.nonpositive');
  if (requireTransit && transitSteps === 0) errors.push('transit.missing');

  return {
    ok: errors.length === 0,
    errors: [...new Set(errors)],
    routeCount: routes.length,
    legCount: legs.length,
    totalSteps,
    transitSteps,
    modes: [...modes].sort(),
    durationSeconds,
    distanceMeters,
  };
}

function nextNineAmEpochSeconds() {
  const now = new Date();
  // 09:00 Asia/Kolkata expressed in UTC. Advance one day if already passed.
  const istNow = new Date(now.getTime() + 5.5 * 60 * 60 * 1000);
  let utc = Date.UTC(
    istNow.getUTCFullYear(),
    istNow.getUTCMonth(),
    istNow.getUTCDate(),
    3,
    30,
  );
  if (utc <= now.getTime()) utc += 24 * 60 * 60 * 1000;
  return Math.floor(utc / 1000);
}

async function main() {
  let auth;
  let token;
  let authAttempts = 0;
  for (const delayMs of [0, 500, 1000]) {
    if (delayMs) await new Promise((resolve) => setTimeout(resolve, delayMs));
    authAttempts += 1;
    auth = await timedFetch('/auth/token', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ bundleId }),
    });
    token = auth.body && auth.body.token;
    if (auth.statusCode === 200 && token) break;
  }
  if (!auth || auth.statusCode !== 200 || !token) {
    throw new Error(
      `authentication failed after ${authAttempts} attempts; last HTTP ${auth && auth.statusCode}`,
    );
  }
  const headers = {
    'content-type': 'application/json',
    authorization: `Bearer ${token}`,
  };

  const summaries = [];
  const latencies = [];
  for (const probe of cityCases) {
    const citySummary = { city: probe.city };
    for (const mode of ['driving', 'transit']) {
      const request = {
        origin: probe.origin,
        destination: probe.destination,
        mode,
        ...(mode === 'transit'
          ? { transit_mode: 'subway', departure_time: nextNineAmEpochSeconds() }
          : {}),
      };
      const result = await timedFetch('/maps/directions', {
        method: 'POST',
        headers,
        body: JSON.stringify(request),
      });
      latencies.push(result.elapsedMs);
      citySummary[mode] = {
        http: result.statusCode,
        latencyMs: result.elapsedMs,
        contract: auditDirections(result.body, { requireTransit: mode === 'transit' }),
      };
    }

    const autocomplete = await timedFetch('/maps/autocomplete', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        input: probe.query,
        location: probe.origin,
        components: 'country:in',
        sessiontoken: crypto.randomUUID(),
      }),
    });
    latencies.push(autocomplete.elapsedMs);
    const predictions = autocomplete.body && Array.isArray(autocomplete.body.predictions)
      ? autocomplete.body.predictions
      : [];
    const first = predictions[0];
    citySummary.autocomplete = {
      http: autocomplete.statusCode,
      latencyMs: autocomplete.elapsedMs,
      resultCount: predictions.length,
      contractOk: predictions.length > 0 && predictions.every((p) => p.description && p.place_id),
    };

    if (first && first.place_id) {
      const details = await timedFetch('/maps/place-details', {
        method: 'POST',
        headers,
        body: JSON.stringify({ place_id: first.place_id, sessiontoken: crypto.randomUUID() }),
      });
      latencies.push(details.elapsedMs);
      const place = details.body && details.body.result;
      citySummary.placeDetails = {
        http: details.statusCode,
        latencyMs: details.elapsedMs,
        contractOk: Boolean(place && place.name && place.geometry && locationOk(place.geometry.location)),
      };
    }

    const geocode = await timedFetch('/maps/geocode', {
      method: 'POST',
      headers,
      body: JSON.stringify({ address: probe.origin }),
    });
    latencies.push(geocode.elapsedMs);
    const geocodes = geocode.body && Array.isArray(geocode.body.results) ? geocode.body.results : [];
    citySummary.reverseGeocode = {
      http: geocode.statusCode,
      latencyMs: geocode.elapsedMs,
      contractOk: geocodes.length > 0 && Boolean(geocodes[0].formatted_address) && Array.isArray(geocodes[0].address_components),
    };
    summaries.push(citySummary);
  }

  const failures = [];
  for (const result of summaries) {
    for (const mode of ['driving', 'transit']) {
      if (result[mode].http !== 200 || !result[mode].contract.ok) {
        failures.push(`${result.city}.${mode}`);
      }
    }
    for (const feature of ['autocomplete', 'placeDetails', 'reverseGeocode']) {
      if (!result[feature] || result[feature].http !== 200 || !result[feature].contractOk) {
        failures.push(`${result.city}.${feature}`);
      }
    }
  }

  console.log(JSON.stringify({
    providerBase: new URL(baseUrl).host,
    sampledAt: new Date().toISOString(),
    authAttempts,
    rawProviderContentPersisted: false,
    operationCount: latencies.length,
    latencyMs: {
      min: Math.min(...latencies),
      p50: percentile(latencies, 0.5),
      p95: percentile(latencies, 0.95),
      max: Math.max(...latencies),
    },
    failures,
    cities: summaries,
  }, null, 2));

  if (failures.length) process.exitCode = 1;
}

main().catch((error) => {
  console.error(`maps parity probe failed: ${error.message}`);
  process.exitCode = 1;
});
