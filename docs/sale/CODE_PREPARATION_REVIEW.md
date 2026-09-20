# Code preparation review — 21 September 2026

This review concerns a source/history license for AI training and software
engineering evaluation. It does not certify a deployable transit alarm. The
existing application logic, documented failed approaches and honest limitations
are part of the asset. New cleanup work is dated separately from original work.

## Fixes justified before packaging

| Finding | Smallest repair made | Why it helps the buyer | Evidence |
|---|---|---|---|
| Local fixes were absent from the older listed branch | Captured the 119 modified files and 24 additional files with their original provenance | Avoids selling an outdated snapshot that omits work the founder described | LOCAL_WORK_CAPTURE.md and commit mapping |
| Live snapping ignored the supplied persisted segment hint | Passed hintIndex into the search helper and allowed stale-hint full-search fallback | Restores the intended continuity interface; original and fixed history remain inspectable | lib/services/snap_to_route.dart; test/services/route_continuity_live_path_test.dart |
| A generic Blue Line could inherit a different city's static palette | Guarded unqualified fuzzy lookup | Prevents the specific demonstrated wrong-colour fallback; numbered generic lines remain a separate finding below | test/segment_builder_test.dart; original preparation commit56cf568 |
| Newly captured tests had type/import drift, stale deviation inputs and a nonportable log path | Corrected Position qualification and RouteSwitchEvent import; used 40m offsets at5m/s; used a writable temporary log directory with actual CSV assertions | Restores useful tests. The deviation threshold is37.5m at5m/s, so40m exercises the existing detector; thresholds and expectations were not weakened | LOCAL_WORK_CAPTURE.md; full pre-exclusion receipt |
| Backend test identity differed from the application contract | Aligned the dummy APP_BUNDLE_ID with com.geowake.app | Tests the actual configured app identity rather than an obsolete test value | tools/sale/verify.py; backend receipt |
| Buyer verifier crashed without .git or could borrow a parent repository's identity | Explicit Git-root detection and source-archive metadata mode | The same runner works for a source ZIP and a Git checkout without misidentifying either | tools/sale/verify.py; checked standalone and nested extracted-directory cases |
| Export CI still attempted withheld dataset gates | Uses the explicit code profile and publishes its exact receipt; preserves the original workflow as history | Avoids representing absent data or vacuous loops as proof of complete verification | .github/workflows/ci.yml; dataset-dependent-tests.json |
| ZUPT exercise resolved dependencies afresh and accepted an insufficiently specific failure signature | Added paired locks, enforce-lockfile, exit1 and exact3-pass/2-failure gate; clarified task/ entry instructions | Reduces dependency drift and false acceptance of unrelated failures | evaluation/zupt-degraded-gating/manifest.json; rerun task3pass2fail/reference5pass |
| Original historical hashes no longer resolved after sanitization | Added a lookup command and explicit maps | Restores a usable navigation path from decisions to original code changes | tools/sale/resolve_original_commit.py |

## Runtime findings retained with the archive

These are source-inspection findings, not newly reproduced rider incidents.
They remain unpatched in this package. Existing green tests do not cover them.
They are useful candidate debugging tasks if a buyer chooses to continue work.

### Alarm snap history may cross a route or session boundary

`lib/services/trackingservice.dart` holds one `_lastSnapResult`, passes it to
`_resolveAlarmRouteState`, and resets it in `resetForTesting` but not the normal
stop path. The state is not owned by a route key or geometry revision. The
snap engine searches near the old segment and only escapes that window above
500m lateral error. A replacement route can therefore use an unrelated segment
hint. The separate ActiveRouteManager history is keyed and does not prove this
alarm path is safe.

Smallest proposed fix: retain previousResult only when its route key and
geometry match the current entry; clear ownership at stop/rearm and geometry
replacement. Preserve continuity within one unchanged route.

Meaningful verification: prime a two-point old route, then replace it with a
101-point route along the same corridor. Deliver actual test GPS updates through
the existing TrackingService seam so `_lastProcessedPosition` changes. Verify
no premature alarm at the old intermediate point and a destination alarm at the
new endpoint. Repeat for a different key, same-key geometry replacement and a
normal stop/rearm. This plan has not been executed and is not a third verified
historical task.

### Recovered sessions wire rerouting differently

The normal-start route-switch listener conditionally migrates alarm state and
calls `_locationStreamHandler.updateRouteGeometryForKey`. The recovery listener
migrates state and emits the event without that geometry/stop-context update.
A recovered trip that reroutes can retain earlier fusion geometry.

Smallest proposed fix: share the existing switch-handler behavior across both
startup paths, preserving same-key refresh handling. Verification must restore
a real route context, reroute, and assert the geometry and transit-stop context
used by sensor fusion. The current recovery test uses empty directions and
mocked distances; observing only a switch event would not establish this fix.
No new sensor/mock scaffolding was added for this sale.

### Generic numbered line names still lack city identity

`DirectionService._getLineColor` treats strings containing “metro line” as safe
for fuzzy matching. A bare “Metro Line1” can match the qualified Mumbai entry.
The existing Blue Line regression proves the earlier repair, not this case.

Smallest proposed fix: require explicit city/operator evidence before applying
a qualified static palette; retain authoritative provider colours. Verify both
generic numbered names and properly qualified names. This is a display issue,
not a reason to rebuild the data catalog or extend product scope.

## Work that does not improve this particular handoff

A new sensor dataset, underground-accuracy campaign, store launch, OEM matrix,
new premium features, framework migration and broad monolith refactor would be
new product work. There is no buyer requirement or transaction evidence showing
that such work is necessary for this archive sale. Avoid changing thresholds or
removing failing assertions to manufacture a green result. Preserve authentic
before/after history and distinguish measured checks from founder reports.

The final verification guide and external manifest identify the delivered inputs.
This review is bounded; it is not a claim that every runtime defect was found.
