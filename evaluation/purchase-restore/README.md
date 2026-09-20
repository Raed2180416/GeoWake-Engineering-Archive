# Historical concurrent-restore regression

The pre-fix source is commit `936d283b3e7f2d4c70a9375f95b7ee9f149c4756`; its immediate child `5877dee569bc5dee80b98398bdcd79d3f705b596` introduced the repair and the original regression test. The standalone task copies pre-fix source and that test byte-for-byte. `reference/` and `reference/solution.patch` hold the separate answer.

Observed 20 September 2026 with Flutter 3.44.6, Dart 3.12.2, and cached package dependencies: task **2 pass, 1 intended failure** (the concurrent call takes 3000 ms, exceeding the original 1000 ms assertion); reference **3 pass**. Logs and exit codes are in `results/`. Run again with:

```bash
FLUTTER_BIN=/home/raed/flutter/bin/flutter ./run_example.sh --both --offline
```

The runner copies inputs to a temporary directory and caps test concurrency at two workers. `task.md` is a newly written retrospective prompt, not an original ticket. The test uses a fake `InAppPurchasePlatform`; this result verifies the adapter's local concurrency behavior, not store billing or entitlement security on a device. The test comments explain the historical fix, so this is a transparent exercise rather than a blind benchmark. The patch is limited to the store adapter; the historical fix commit also contained unrelated changes.
