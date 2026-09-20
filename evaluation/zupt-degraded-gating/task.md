# Reconstructed evaluation task: false zero-velocity update in GPS-denied travel

This task statement is reconstructed from the historical commit and its regression test. It is not represented as an original issue ticket or a contemporaneous customer report.

Start at repository commit `d0d76e5a391f62bcb6bc9a41cc66c46709762224`. In `lib/core/ekf/zupt_detector.dart`, a GPS-denied, smoothly moving train can satisfy the quiet-IMU and low-estimated-velocity conditions when the EKF has not learned cruise speed. That produces a false zero-velocity update. Correct the degraded-mode confirmation rule so this moving case does not confirm, while an ultra-quiet dwell with a stationary motion hint still can. Preserve normal-mode behavior.

Apply `test.patch` to the starting commit, or place the byte-identical `fixed-regression-test.dart` at `test/core/ekf/zupt_degraded_gating_test.dart`. The acceptance command is `flutter test --no-pub --reporter expanded test/core/ekf/zupt_degraded_gating_test.dart` after `flutter pub get --offline` with cached dependencies. The five tests in that historical test file are the evaluation gate. The reference change is stored separately in `solution.patch` and must not be given to a model being evaluated.

The numerical cases are deterministic test inputs attributed by the original developer to an instrumented ride probe. The underlying raw ride recording is not included in this example, so the evaluation verifies code behavior rather than field accuracy.
