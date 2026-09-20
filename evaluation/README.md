# Two verified historical code-regression exercises

1. `zupt-degraded-gating/`: quiet moving train classified as a stop during GPS loss; 3 pass/2 fail before, 5 pass after.
2. `purchase-restore/`: concurrent caller loses its restore completion; 2 pass/1 fail before, 3 pass after.

Each includes original source/tests, original commit and byte-hash provenance,
a new retrospective prompt, a separate reference answer, a standalone runner
and observed logs. These are transparent historical exercises, not blind
benchmarks. Keep reference code, answer patches and logs away from candidate
agents during assessment. Neither needs raw rides, maps credentials or a real store.
