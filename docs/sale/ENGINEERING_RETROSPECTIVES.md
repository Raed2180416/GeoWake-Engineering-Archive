# Engineering retrospectives

Written 20 September 2026 from existing code and Git history. These are new
explanations of genuine changes, not historical tickets, reviews, or records of
a multi-person team. Proposed evaluation tasks below are not yet a validated
benchmark or a priced task dataset.

## GPS-denied cruising mistaken for a stop

Historical finding: `b1b30f5`. Pre-fix revision: `d0d76e5`.
Fix: `f956929`.

The zero-velocity detector could interpret sufficiently quiet GPS-denied
motion as a stop and pin the position estimate. The fix makes degraded-mode
zero-velocity updates depend on stricter quietness and motion corroboration.
Read `lib/core/ekf/zupt_detector.dart` alongside
`test/core/ekf/zupt_degraded_gating_test.dart`.

A proposed evaluation asks an agent to preserve true-stop handling while
preventing a quiet cruising segment from repeatedly resetting velocity. The
regression test supplies a checkable behavioral target. The historical research
also discusses real rides, but those externally referenced fixtures are absent
from this checkout, so their reported improvements are not freshly reproduced.

To establish a benchmark pair, isolate the pre-fix revision, carry over only
the regression test, verify that it fails for the intended reason, then apply
the historical fix and verify that it passes. Until both outcomes are captured,
label this a task candidate, not a verified fail-to-pass example.

## Concurrent purchase restoration

Pre-fix revision: `936d283`. Fix: `5877dee`.

The purchase backend contains coordination logic for concurrent restore calls.
Read `lib/services/monetization/purchase_backend_impl.dart` alongside
`test/monetization/purchase_backend_impl_test.dart`. The tests document the
request/response and concurrency behavior without requiring real store access.

A proposed task asks an agent to make concurrent restoration share the
appropriate operation and result, preserving failure cleanup and later retries.
Run the historical regression at both revisions before calling it a validated
task. Passing the headless test does not establish Play Billing behavior on a
device or entitlement security in a production deployment.

## Suggested evaluation delivery fields

Each accepted task should contain a new task ID, retrospective creation date,
original commit references, a natural-language problem statement, exact setup,
the test patch, observed pre-fix failure, observed post-fix success, runtime
limits, expected external services, rights scope and grading boundaries. Keep
the solution and ground-truth patch separate from agent-visible inputs.
