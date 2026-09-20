# Feature and implementation status

This is an index to the detailed guides, not a list of deployed product promises.
“Implemented” means a source path exists in the captured revision. The execution
receipt and test index separately identify what was exercised. The archive
contains Android-focused work; desktop/web/iOS project scaffolding does not
establish equivalent runtime behavior.

| Area | Status in the archive | Evidence and practical limit |
|---|---|---|
| Search, recents, route choice | Implemented | [Journey](JOURNEY_AND_ROUTING.md); remote lookup needs a configured provider |
| Cached routes and offline continuation | Implemented | Journey; uncached offline route creation can fail visibly |
| Distance, time and metro-stop alarms | Implemented | Journey; each consumes different route/progress state |
| Pre-boarding warning | Implemented experimental rule | Journey; 40% was intended for later tuning; toggle asymmetry remains documented |
| Transfers and intermediate events | Implemented | Journey; route/event compilation and per-leg progress |
| Snapping, deviation and sustained off-route state | Implemented | Journey; hysteresis and timing are testable, GPS quality remains an input assumption |
| Rerouting and alternate-route switching | Implemented | Journey; request policy, route identity, cache and state reconciliation |
| Background handshake, snapshot and recovery | Implemented with captured fixes | Journey and [capture](LOCAL_WORK_CAPTURE.md); headless checks do not certify OEM behavior |
| Notification, full-screen UI, sound, vibration, native backstop | Implemented Android integration | Journey; no fresh physical-device delivery claim |
| EKF, IMU features, tilt and motion classification | Implemented experimental tracking | [Underground](UNDERGROUND_EVOLUTION.md); real-ride reports include large errors |
| ZUPT and station association | Implemented experimental logic | Underground; a stop event is not proof of station identity; verified false-ZUPT regression supplied |
| Stop-event anchoring and between-station profiles | Offline research | Underground; founder confirms nothing beyond experiments |
| Reachability and monotonic-clock work | Implemented, conditionally reasoned | Underground; safety depends on valid anchors and speed/clock assumptions |
| Optional physics tightening | Implemented, disabled by default | Underground; distinct from the unmerged sensor-gated stop proposal |
| Free alarm and Pro entitlement policy | Implemented | [Supporting systems](SUPPORTING_SYSTEMS.md); essential alarm capabilities unconditional |
| Purchase/restore and prepaid expiry | Implemented with captured backend work | Supporting systems; store boundaries mocked in local tests |
| Ads, rewarded access and post-arrival actions | Policy/integration code | Supporting systems; no revenue or affiliate-contract claim |
| Journey sharing and followed rides | Implemented client and server | Supporting systems; expiry, revocation and per-share capabilities; no hosted account transfer |
| Guardian | User-composed message flow plus extension point | Supporting systems; automatic sender not wired by default |
| Anti-theft | Sensor-state implementation | Supporting systems; no labeled theft benchmark or accuracy claim |
| Consent, erasure, binning, contribution caps, aggregate merge | Experimental code/scaffold | Supporting systems; default-OFF consent, disabled egress, no population dataset |
| Telemetry, problem reporting and field diagnostics | Implemented separate paths | Supporting systems and [data flow](DATA_FLOW.md); raw recordings are outside core delivery |
| Maps proxy, auth, cache, quotas, kill switch | Implemented backend | Supporting systems; local tests use dummy credentials/mocks |
| Alternative maps-provider migration | Design contract and probe | Supporting systems; no completed deployment claimed |
| Route memory and home widget | Implemented foreground handoff | Journey; widget action can open normal app arming flow |
| Localization | Five ARB inputs | Supporting systems; English, Hindi, Bengali, Tamil, Telugu |
| Simulation dashboard, replay, clock and scale tooling | Implemented development tools | Guides and test index; dataset-dependent route/scale cases are explicitly excluded in the export code profile |
| Marketing site, pricing, launch and expansion plans | Historical context | [Historical index](../archive/README.md); not current commitments or revenue evidence |
| Friend-phone sensor recordings | Separate optional candidate | Rights and exclusions; transformed local bundle, not included in core code grant |

The machine-readable source index assigns every delivered tracked path a feature
or an explicitly broad repository/platform group. The [52-decision register](DECISIONS.csv)
connects choices and known rationale to sources. It does not invent missing intent.
