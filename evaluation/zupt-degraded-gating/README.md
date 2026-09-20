# Historical ZUPT regression: standalone evaluation

This package reproduces a real July 2026 code change with its original regression
test. A GPS-denied train cruise could be misclassified as stationary when the
filter velocity remained near zero. The fix strengthens the corroboration needed
for a zero-velocity update.

**Observed again on 20 September 2026:** the task has 3 passing tests and the
2 intended failures; the reference has all 5 tests passing. The minimal harness
uses Flutter 3.44.6 / Dart 3.12.2. It needs no Maps key, phone recording, app art,
OneUI audio, full app dependency tree or original Git checkout.

## Run

```bash
FLUTTER_BIN=/path/to/flutter ./run_example.sh --both --log-dir /tmp/zupt-results
```

Use `--offline` when the SDK's test dependencies are cached. `--task` or
`--reference` runs only that side. The script copies inputs into a temporary
directory, checks the expected outcomes and leaves logs at the requested path.
An expected task failure is a successful reproduction, not a repaired solution.

## Keep task inputs separate from answers

- `task.md` and `task/` are the candidate-facing problem, pre-fix source and original test.
- `reference/` and `solution.patch` contain the answer. Do not expose them to an agent during evaluation.
- `test.patch` / `fixed-regression-test.dart` preserve the original test in convenient forms.
- `minimal-*-test.log` record this standalone run. Earlier `pre-fix-test.log` and `post-fix-test.log` record the original full-dependency archive check.
- `manifest.json` pins original commits, unchanged source/test hashes and the new packaging artifacts.

Original pre-fix: `d0d76e5a391f62bcb6bc9a41cc66c46709762224`.
Original fix: `f95692932f8d6051f3b56e742de91e49c9144e3e`, its immediate child.
The same original regression test from the fix is used on both sides. The only
new harness inputs are the minimal package configuration and runner; source and
test bytes were compared directly with the original Git objects.

The problem statement was written retrospectively in September 2026. It is not
an original issue or customer ticket. Historical comments attribute some test
values to a ride probe; this exercise does not replay raw measurements or prove
physical alarm delivery. Use the sanitized-history mapping for corresponding
commits in the delivered repository.
