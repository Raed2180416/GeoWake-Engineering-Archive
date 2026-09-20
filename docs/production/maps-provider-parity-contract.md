# Maps provider parity contract

Snapshot: 2026-08-07. This is a code-grounded migration contract, not a claim
that an Oracle replacement is deployed. The executable probe is
`geowake-server/scripts/maps-parity-probe.js`; it deliberately retains the
current `/api/maps/*` boundary so Google and a candidate provider can be tested
with the same inputs without persisting either provider's raw content.

## What currently depends on Google Maps

| Surface | Live call chain / consumers | Behavior that must survive a switch |
|---|---|---|
| Basemap renderer | `homescreen.dart`, `maptracking.dart`, `preload_map_screen.dart`, `unified_dashboard.dart`, `deviation_dashboard.dart` via `google_maps_flutter` | First map frame, pan/zoom, tap and double-tap, draggable destination pin, camera fit/animation, user/destination/station markers, colored route and diagnostic polylines, dark/light coherence, accessibility |
| Autocomplete | `HomeScreen -> PlacesService -> ApiClient -> POST /maps/autocomplete` | 450 ms debounce, local recents merged first, no remote one-character query, India/country bias, location bias, useful ranked descriptions, stable provider-neutral IDs, empty/error fallback |
| Place resolution | `HomeScreen -> PlacesService -> POST /maps/place-details` | Selected suggestion resolves to a name and finite lat/lng; the stable ID deduplicates recents; selection remains fast and does not move after a newer selection |
| Reverse geocoding | map pin label, country bias, origin/destination state check via `POST /maps/geocode` | Formatted address plus country and administrative-area components; map pin still works offline with `Dropped pin`; state checks fail open only when the lookup itself is unavailable |
| Driving route | `DirectionService -> ApiClient -> POST /maps/directions` | Alternatives, duration/distance, route and per-step geometry, step modes, start/end coordinates, deterministic fastest-route selection, deviation reroute, time/distance alarm inputs |
| Transit/metro route | same endpoint with `mode=transit`, rail/subway and optional departure time | Walk/drive/transit legs, multi-leg total duration, transfer topology, station names/coordinates, line name, vehicle type, intermediate stop count, scheduled times, fastest metro-containing alternative, closed-service future-time retry |
| Tracking geometry | `RouteSessionManager`, `TransferUtils`, EKF/reachability, `MapTracking`, offline coordinator | Google encoded overview and step polylines currently define the shared arc-length domain for progress, stop positions, transfer boundaries, reroute detection and display. Any adapter must preserve one internally consistent geometry domain. |
| Nearby transit search | `/maps/nearby-search` and `ApiClient.getNearbyTransitStations` | No production caller was found. Prefer the bundled city-wide station index and remove this billed/dead endpoint after a call-site gate confirms it remains unused. |
| Provider IDs and JSON shape | recents store `place_id`; dozens of consumers read Google Directions keys directly | During phase 1 the replacement adapter must emit the same compatibility schema. Phase 2 can introduce provider-neutral models and migrate `LatLng`, `Marker`, `Polyline`, camera controllers and provider IDs behind explicit interfaces. |

Switching Maps does **not** remove Google Play Billing, AdMob, or Android's
location stack. Those are separate production dependencies and release gates.

## Compatibility schema enforced by the probe

Directions must return `status=OK`, at least one route and leg, positive total
distance/duration, a non-empty overview polyline, non-empty step lists, a mode
and polyline for every step, and—for transit—at least one transit step with:

- non-negative integer `num_stops`;
- line name/short name and vehicle type;
- named departure and arrival stops with finite coordinates.

Autocomplete must return ranked `{description, place_id}` entries. Details must
resolve the ID to `{name, geometry.location.lat/lng}`. Reverse geocoding must
return `formatted_address` and `address_components` because live UI and route
jurisdiction checks consume both.

## No-regression promotion gates

Run the exact same owned query/route corpus through Google and the candidate in
shadow mode. Compare user outcomes, not byte-identical paths:

1. Search top-five success and selected-place coordinate correctness per city.
2. Mode sequence, boarding/alighting stations, ordered transfers, destination,
   and route feasibility. A different street path is acceptable; a different
   transit topology is a review failure.
3. Threshold validation result and every alarm target (pre-board, transfer,
   destination) must agree. The multi-city route permutation test must retain
   zero wrong-line, wrong-city or off-segment station anchors.
4. Candidate latency/error rate must be measured against the same-time Google
   control. Do not promote if p95 grows by more than 10%, error/empty-result rate
   grows by more than 1 percentage point, or map-frame jank materially worsens.
5. ETA quality must be compared with observed journeys; provider-vs-provider ETA
   agreement alone is not ground truth.
6. Roll out independently per launch city. Google route content cannot be
   combined with a non-Google map under the current service-specific terms, so
   fallback switches the route provider **and renderer together** (Google route
   + Google map, or owned route + MapLibre). Bengaluru success must not silently
   promote Mumbai, whose transit feeds and agencies are more fragmented.

The command below performs a small live schema/topology/latency sample and
stores no raw provider response:

```bash
PROBE_API_BASE_URL=https://host.example/api \
  node geowake-server/scripts/maps-parity-probe.js
```

## Oracle-hosted target

- MapLibre Native for the renderer, with versioned MapLibre/PMTiles-compatible
  India tiles served from object storage/CDN rather than a single VM.
- OpenTripPlanner over OSM plus GTFS/GTFS-RT for transit itinerary topology.
- Valhalla (or a measured equivalent) for driving/walking and map matching.
- Pelias/Photon-class geocoding/search, backed by an India-tuned address index.
- The existing ordered metro dataset as a validation/anchoring asset—not as a
  substitute for GTFS shapes, trips, calendars, stop times, transfers and
  realtime service state.

A single free Oracle VM is suitable for a shadow pilot, not yet evidence for
massive load or high availability. Production promotion needs load tests,
shared quotas/cache state, data-refresh automation, backups, monitoring, a
second failure domain, and a rehearsed fallback.

## Current contradiction to resolve before launch

The server no longer caches Google Directions/Places payloads. The current
Google Maps service-specific terms permit temporary caching of Directions
latitude/longitude values for up to 30 days, but not the app's entire raw
response. Mobile `RouteCache` still persists full directions for offline
restoration, `TrackingStateStore` persists a reduced response, and disabled
`RouteLogger` can persist the full response when manually enabled. That offline
recovery is safety-critical, so do not simply delete it: move route generation
to the owned provider, make storage permission an explicit provider capability,
and then retain the full owned route. Until then this is a launch blocker that
needs counsel/account-term confirmation or a Google-safe reduced snapshot.
