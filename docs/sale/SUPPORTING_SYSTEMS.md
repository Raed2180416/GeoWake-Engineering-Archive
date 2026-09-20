# Supporting systems and the decisions behind them

Prepared 20 September 2026. This guide describes code in the local-work capture
`f4daa94` and subsequent reproduction repairs recorded in `LOCAL_WORK_CAPTURE.md`. It complements
[Journey and routing](JOURNEY_AND_ROUTING.md) and
[Underground evolution](UNDERGROUND_EVOLUTION.md). A source implementation,
a design proposal, and observed field behavior are different kinds of evidence.
The labels below keep those distinctions visible.

## Entitlements, purchases and the free alarm

**Intent recorded in source:** paid features must not make a basic wake alarm
unavailable. `PremiumService` exposes four unconditional free capabilities:
core alarm, basic reliability, the backstop and one active route. Sound
customization, widget, guardian and anti-theft have separate Pro getters.
The decision is expressed as pure policy so tests can evaluate the entire
entitlement state without contacting a store.

**Flow:** purchase/restore events enter `IapPurchaseBackend`, move through
`MonetizationService`, update `PremiumService`, then notify listening UI.
Persistence records permanent ownership and temporary expiry separately.
Malformed persisted state resolves to Free. This is deliberately a denial of
paid access with the core alarm still available, not a startup failure.

**Evolution:** the archive preserves one-time Pro and rewarded-day-pass work,
then a daily/weekly/monthly/yearly prepaid ladder. The captured local changes
use prepaid subscriptions with store-verified expiry, rather than treating
every observed consumable identifier as a freshly purchased duration.
`playBillingVerifier.js` asks the Android Publisher API for matching line items,
active/grace/canceled-but-unexpired state and expiry. Its credential is external
configuration. Tests mock that boundary; no live sale or receipt is claimed.
Asynchronous purchase events, pending payments, restore coalescing and startup
reconciliation provide useful examples of state arriving after an initiating
request has returned.

**Read:** `lib/services/monetization/premium_service.dart`,
`monetization_service.dart`, `purchase_backend.dart`, `purchase_backend_impl.dart`;
`lib/screens/monetization/paywall_screen.dart`;
`geowake-server/src/routes/billing.js`, `src/services/playBillingVerifier.js`.
**Check:** `test/monetization/` and `geowake-server/test/billing.test.js`.
`PASS_PRICING_ANALYSIS.md` records historical commercial thinking; its prices
are not buyer valuation or evidence of actual store configuration/revenue.

## Advertising and post-arrival actions

**Decision:** an ad must not cover or delay the wake, lock-screen or alarm
surface. `AdPolicy` keeps an explicit denylist and separate eligible surfaces.
The post-arrival frequency cap is expressed as a rule over completed rides;
Pro suppresses ads. Rewarded access is an opt-in path rather than a required
step in arming a route. These are policy implementations, not ad-income proof.

**Flow:** arrival/teardown opens the post-arrival screen, which consults policy
and the ad facade. The separate `PostArrivalService` constructs station/zone
labels and generic onward-action kinds. Its model rejects coordinate- or
identifier-looking strings and projects telemetry to action kind/primary flag.
The historical plan proposed last-mile ride, food and directions referrals;
an action model is not a signed affiliate partnership or revenue stream.

**Read:** `lib/services/monetization/ad_policy.dart`, `ad_service.dart`,
`post_arrival_service.dart`; `lib/screens/monetization/post_arrival_screen.dart`;
`lib/widgets/gated_banner_ad.dart`, `post_arrival_card.dart`.
**Check:** post-arrival decision, interstitial, widget and privacy tests in
`test/monetization/`. Training use: policy tables, safe sequencing of optional
side effects, and separating business intent from actually integrated code.

## Sharing, followed rides and capability boundaries

**Flow:** a share session holds an opaque ID, destination label, creation and
expiry times, status and optional backend ID. A share link reaches another
device through the OS share surface. `FollowedRidesService` persists the
subscription, polls status and retains the last known view when a request
fails. The service supports `enRoute`, `arrived`, `revoked` and `expired` states;
six hours is the basic session's default TTL, not an indefinite commitment.

`ShareSnapshot` holds the latest position, not a trajectory array. Its
five-decimal rounding still represents fairly precise location; older comments
calling that inherently non-identifying should not be read as an anonymity
guarantee. The core source corpus contains the model and transport code, not
real users' sharing sessions.

**Evolution:** earlier code used a configured bearer for transport. Captured
local work introduces per-share read/write capabilities so the mobile binary
does not require a universal write secret. The backend supplies status pages,
expiry/revocation, bounded in-memory state, request limits and no-store
responses. A no-op transport supports offline operation. The archived default
URL is a historical configuration, not a transferred service account.

**Read:** `lib/services/share/journey_share_models.dart`,
`journey_share_service.dart`, `live_share_backend.dart`,
`share_backend_config.dart`, `share_deep_link.dart`, `share_link_builder.dart`,
`followed_rides_service.dart`; `lib/screens/friends_rides_screen.dart`;
`backend/share/server.js`.
**Check:** `test/share/`, `backend/share/server.test.js`.
Training use: lifecycle semantics across client/server, capability-scoped
authorization, expiration, stale reads and state recovery. No live target
testing is needed to study those behaviors.

## Guardian mode and contact delivery

**Intent:** a selected contact receives the journey link and can see arrival.
Guardian is an optional paid feature that observes the journey lifecycle;
errors must not affect the core alarm. The captured work includes an explicit
contact-picker boundary and tests for entitlement/contact state.

**Delivery distinction:** the default interaction composes a message in the
user's SMS or WhatsApp application for the user to send. `autoDeliverySender`
is an injectable, normally unwired extension. At the destination alarm,
Guardian marks the share arrived. It does not open a composer over the wake
alert. An automatic arrival message requires that separate sender integration.
This distinction prevents a planned automation from becoming a false feature
claim in the buyer index.

**Read:** `lib/services/share/guardian_service.dart`,
`guardian_contact_picker.dart`; `lib/screens/guardian_setup_screen.dart`;
`lib/widgets/share/guardian_settings_section.dart`.
**Check:** `test/share/guardian_service_test.dart` and the share lifecycle tests.

## Anti-theft sensing

**Implemented approach:** accelerometer magnitude is compared with a rolling
baseline, with gyroscope corroboration to reduce false triggers; optional
charger removal provides another signal. The code has a calibration period,
sensitivity levels, confirmation/cooldown state and dismissal. The baseline
uses approximately 20 Hz subscriptions, a five-second calibration period and
ten-second cooldown. These constants are implementation choices, not measured
theft-detection accuracy.

**Rationale recorded in source:** an isolated acceleration spike should not
alone be sufficient to treat ordinary train movement as a snatch; sensor
corroboration and cooldown aim to limit nuisance alarms. Captured changes
strengthen entitlement handling. Monitoring failures are contained so the
destination alarm can continue.

**Read:** `lib/services/anti_theft_service.dart`,
`lib/screens/anti_theft_setup_screen.dart`.
**Check:** anti-theft tests, including the captured
`test/services/anti_theft_entitlement_test.dart`.
Training use: signal-state machines, threshold tradeoffs and independent
failure domains. No labeled theft dataset or accuracy percentage is offered.

## Consent and the experimental aggregate-data surface

**Flow:** a completed trip reaches `DataAssetPipeline`; explicit current-version
consent is checked before station binning and local aggregation. Origin and
destination are converted to station IDs, hour/day-type bins and bounded cell
contributions. Consent withdrawal disables sharing and triggers local erasure
with an erasure record. Corrupt or old-version consent resolves to disabled.

**Concrete constants:** default egress is disabled; endpoints are empty or
build-time inputs; the default sinks are no-ops. The source defines a threshold
of 100 contributing users, four distinct cells per user/day, at most one
contribution per cell/day and a stated epsilon of 0.44 per cell. Historical
overviews saying `k=5` are stale relative to this source.

**Type boundary:** `ReleaseCandidateMatrix` is an on-device candidate;
`OdFlowMatrix` / released cells represent another stage. The backend merge
engine has an in-memory implementation for combining cell counts and device
sets, applying suppression and noise, and returning summaries. This is a
methodology and code scaffold. It does not establish a population dataset,
cross-device privacy certification, calibrated demand data, or a functioning
data business. `buildReleaseCandidate` and actual transmission are different
operations, an important distinction for a code-reading task.

**Read:** `lib/services/data_asset/`, especially `data_asset_config.dart`,
`mobility_consent_service.dart`, `contribution_cap.dart`, `station_binner.dart`,
`od_aggregator.dart`, `aggregate_schema.dart`, `data_asset_pipeline.dart`;
`geowake-server/src/utils/mergeEngine.js`, `src/routes/aggregate.js`.
**Check:** `test/data_asset/` and backend aggregate tests where present.
Training use: consent state, erasure, typed data boundaries, injected storage
and the difference between local and central aggregation assumptions.

## Telemetry, diagnostics and error reporting

**Intent:** observe alarm outcomes, GPS loss/recovery, reachability and failures
without letting diagnostics interrupt the wake path. Typed helpers accept
coarse identifiers and durations; a generic event model routes to injected
sinks. Non-finite numbers are sanitized for JSON encoding. Sink failures are
caught. The in-memory buffer is bounded; file output is rotating JSONL with a
flush interface, and HTTP output is separately configured.

Telemetry is separate from raw field diagnostics. The captured
`GEOWAKE_FIELD_DIAGNOSTICS` flag defaults false and controls local raw IMU/GPS/EKF
recording for experiments. Neither a sink interface nor a consent comment
proves all historical emitted content is safe; the optional recording bundle
has its own data dictionary and transformations.

**Read:** `lib/services/telemetry/`, `lib/core/logging/app_logger.dart`,
`lib/core/ekf/ekf_logger.dart`, `lib/services/route_logger.dart`,
`lib/screens/report_problem_screen.dart`, `lib/config/app_config.dart`.
**Check:** `test/telemetry/`, `test/report_problem_screen_test.dart`.
Training use: nonblocking observability, serialization edge cases, rotating
storage and error paths that must not recursively fail.

## Maps/API backend and cost controls

**Flow:** client `ApiClient` obtains a device token, then routes Places,
Directions, geocoding and nearby-search requests through Express. Server-side
credentials remain external. Middleware applies a kill switch, authentication,
per-token quota, API-family quota and request throttling before provider calls.
Structured request parameters key the response cache. Provider response status
is checked so an error body returned with HTTP 200 is not cached as success.

**Rationale:** the route flow repeatedly asks similar questions; caching and
session tokens reduce avoidable provider requests, while quotas bound cost.
These are distinct from the later plan to replace paid Maps services. The
captured `docs/production/maps-provider-parity-contract.md` and parity probe
describe compatibility work; they do not prove a completed alternative routing
provider or cost-free infrastructure.

**Read:** `lib/services/api_client.dart`, `places_service.dart`,
`direction_service.dart`; `geowake-server/src/server.js`, `routes/maps.js`,
`controllers/mapsController.js`, `middleware/mapsGuard.js`, `utils/cache.js`,
`utils/quotaTracker.js`, `controllers/authController.js`.
**Check:** backend auth, quota, kill-switch, Maps and error-body tests.
Training use: request/response contracts, caching correctness, cost constraints
and provider compatibility. Device-token issuance is not a user-account system.

## UI, localization, widgets and developer tools

The app has five ARB locale inputs: English, Hindi, Bengali, Tamil and Telugu.
Generated localization files and a Flutter scaffold are separate from manual
feature logic. An old architecture statement of 80+ languages is not supported
by these checked-in inputs. Themes, localization, settings, ringtone selection
and the map UI are indexed as user-facing components, not counted as separate
products.

The widget's native provider, Dart render state and arm handler bridge cached
route context into the normal foreground arm flow. Developer entry points
(`main_playground.dart`, `main_unified_dashboard.dart`,
`main_aggregate_dashboard.dart`) expose route, deviation, EKF, speed/time and
constraint controls. Their simulation inputs let a reviewer reproduce state
transitions without treating a simulated trip as a recording.

**Read:** `lib/dashboard/`, `lib/debug/`, `lib/testing/`,
`lib/services/testing/`, `lib/services/widget/`, `lib/l10n/`, `lib/themes/`;
Android `GeoWakeWidgetProvider.kt`; `tools/` and `scripts/` for fixture/data
processing. **Check:** `test/dashboard/`, `test/widget/`, replay/scale tests.
The 112-second demo supplies visual context for these tools. It is not a
commit-specific runtime test of the final archive.

## Planned continuation preserved as historical context

The business/research notes explored city expansion, better underground event
detection and calibration, maps-provider substitution, pricing, marketing and
autonomous operations. Those documents remain useful evidence of the problems
being considered. Their imperatives are archived plans, not instructions to
the buyer and not commitments by the seller. The founder ended the product
effort because of the cost of obtaining suitable underground data. The offered
value is the accumulated engineering corpus, including unresolved questions.
