# Verification record

## Latest independently executed code and test revision

GitHub CI passed at **`0752b78e5ec3ed4b99b97324f8788bb05d1216e5`**:
[run 35531609869](https://github.com/Raed2180416/GeoWake-Engineering-Archive/actions/runs/35531609869).
It executed 1,423 visible Flutter cases, 61 Express tests and 16 sharing tests;
analysis returned zero errors and warnings, with 77 informational findings.
The code profile excludes eight dataset-dependent files. Its 210 hidden harness
events are not extra tests.

That run measured **10,362 / 15,923 Flutter lines (65.08%) in 133 instrumented
files**, and **303 / 417 Express lines (72.66%) in 16**. The
[coverage snapshot](../../coverage/README.md) publishes standard LCOV,
line-only Cobertura and a machine-readable summary with hashes. No sharing or
whole-repository coverage is claimed. Every later CI run publishes its own
exact-revision reports and job summary; the external delivery manifest selects
the final successful run.

Unlike the earlier export, `0752b78` includes a test-only repair to await the
guardian arrival callback and completed share-state update before teardown.
The earlier timing-based test was flaky on CI. Production alarm behavior was
unchanged. The separate secret-scanning configuration compatibility repair is
also recorded in [the preparation review](CODE_PREPARATION_REVIEW.md).

## Earlier verification scopes

| Check | Original prepared source `49a98bc` | Cleaned source `8b96ef8` |
|---|---:|---:|
| Visible Flutter cases passing | 1,466 | 1,423 |
| Explicitly excluded test files | 0 | 8 dataset-dependent files |
| Hidden harness events (not counted above) | 218 | 210 |
| Express tests / suites | 61 / 9 | 61 / 9 |
| Sharing tests | 16 | 16 |
| Flutter analysis errors / warnings | 0 / 0 | 0 / 0 |
| Flutter measured lines / files | 11,436 of 16,800 / 133 | 10,337 of 15,923 / 133 |
| Express measured lines / files | 303 of 417 / 16 | 303 of 417 / 16 |

Each tree has 185 `lib/` Dart paths; two generated catalog paths become empty
schema interfaces in the cleaned copy. Coverage is over the measured files,
not a percentage of the entire repository. Three literal placeholder tests
are identified in the source index. Hidden harness events are not extra tests.

The full cleaned-tree probe was also run: eight failures at the withheld
catalog/route boundaries in five files. The code profile excludes those files
plus three data gates that can otherwise return early or pass vacuously.
[The exclusion map](../../tools/sale/dataset-dependent-tests.json) gives each
reason. No test assertion or alarm threshold was weakened to obtain a pass.
The code profile is not an equivalent replacement for the full data-dependent
suite and does not establish that the app operates with empty metro catalogs.

The [export receipt](verification/verification.json) records exact commands,
SDK, timestamps, profile, excluded files, exit codes and log hashes. Logs and
LCOV files in the same folder are the export run. The earlier full-data receipt
is retained separately; its raw logs stay private with the excluded inputs.
The old export receipt remains evidence for `8b96ef8`; it is not the receipt
for the later guardian test repair. The latest CI run and external final
manifest identify the actual delivered revision. The earlier documentation's
10,338-line numerator was a transcription error; the preserved LCOV records
10,337 covered lines.

The two exercises in `evaluation/` independently reproduced original failures
and fixes with unchanged historical tests. They need no withheld datasets.
All checks are headless, run locally or in GitHub CI. Missing external real-ride tests are not field
validation; no current physical-device, OEM, live Maps or store-billing proof
is claimed. The older debug APK receipt is not a build of this export.

To rerun the available checks:

```bash
python3 tools/sale/verify.py --profile code --out /tmp/geowake-verification
```

Use `--profile full` only to attempt the original full suite with compatible,
properly licensed data. The final receipt starts from a clean committed tree.
An existing test generates an ignored diagnostic trace; it is not authored source.
