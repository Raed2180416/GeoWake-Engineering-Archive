# Coverage evidence

This checked-in snapshot comes from the successful GitHub verification of
`0752b78e5ec3ed4b99b97324f8788bb05d1216e5`:
[run 35531609869](https://github.com/Raed2180416/GeoWake-Engineering-Archive/actions/runs/35531609869).
Its source revision is recorded in [the summary](coverage-summary.json), along
with hashes of the original reports and every instrumented source file.

- Flutter: **65.08%**, 10,362 / 15,923 lines in 133 instrumented files.
- Express: **72.66%**, 303 / 417 lines in 16 instrumented files.
- Eight dataset-dependent test files are outside the `code` profile.
- Sharing coverage and whole-repository coverage are not measured.

[LCOV](lcov.info) uses repository-relative paths; backend paths begin with
`geowake-server/`. [Cobertura](cobertura.xml) is a line-only conversion of the
same measurements. Its zero branch denominator means no branch measurement in
that conversion, not measured zero branch coverage. The original backend
function and branch records remain in LCOV. The summary's combined line total
describes these instrumented files only.
Cobertura requires numeric complexity attributes; their zero values are format
placeholders, not measured code complexity. Its timestamp comes from the
verification receipt.

Each new CI run produces its own `coverage` artifact and a job summary, pinned
to that run's revision. Those are the current results; this snapshot remains
dated evidence. To regenerate reports from a successful verification directory:

```bash
python3 tools/sale/report_coverage.py --verification-dir /tmp/geowake-verification --out /tmp/geowake-coverage
```

Running `flutter test --coverage` locally overwrites `coverage/lcov.info` with
Flutter-only output. Use the command above to build the combined report; retain
the receipt and original reports when intentionally updating this snapshot.

DataVendor reported coverage as unmeasured for the estimate taken before these
standard paths and CI summaries were added. Its public documentation does not
specify an accepted coverage parser or format. These files expose actual
measurements; they do not imply the platform has imported or credited them.
