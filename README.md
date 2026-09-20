# GeoWake — never miss your stop

**A Flutter/Android transit-alarm codebase, with its development history, tests and underground-tracking experiments, prepared for AI training and software-engineering evaluation.**

I built GeoWake so I could sleep, read or switch off on a journey without
missing my stop. Choose a destination and how early to be alerted; the app
tracks the route and prepares the wake alarm. The code covers pre-boarding,
distance/time/stops alarms, deviation and rerouting, background recovery,
native Android delivery and two Node backends.

Underground tracking became the hardest part. My initial aim was to combine
GPS and phone motion to follow the whole route, continuing on IMU measurements
when GPS disappeared. Ordinary movements of a phone in a passenger's hand or
pocket made that unreliable. The work progressed from raw acceleration
integration to a route-constrained EKF, then toward detecting the train's
braking, dwell and departure patterns and connecting them to known stops.

The archive includes that applied research: estimation and uncertainty code,
ZUPT and station association, conservative alarm bounds, replay tests,
diagnostic reports, failed approaches and historical fixes. The stop-event
approach remained experimental. I stopped pursuing the product because
obtaining enough suitable data to tune and validate it became too expensive.
[The research history](docs/sale/UNDERGROUND_EVOLUTION.md) separates implemented
code, reported offline findings and work that remained open.

I am offering the existing code and engineering records for model training and
software-engineering evaluation. No ongoing product-development engagement is
included.

**Data scope:** mixed-source metro catalogs and certain route/scale data are
withheld. Labeled schema stubs preserve code interfaces. Read the
[export scope and verification effects](docs/sale/EXPORT_SCOPE.md).

## Start here

| Review question | Guide |
|---|---|
| What is offered and why is it useful? | [Buyer brief](docs/sale/BUYER_BRIEF.md) |
| Where is everything? | [Buyer index](docs/sale/README.md), [feature status](docs/sale/FEATURES.md) |
| What happens from search to wake-up? | [Journey, pre-boarding, deviation and rerouting](docs/sale/JOURNEY_AND_ROUTING.md) |
| Why did the underground approach change? | [Underground evolution](docs/sale/UNDERGROUND_EVOLUTION.md) |
| What about purchases, sharing, guardian, anti-theft and data? | [Supporting systems](docs/sale/SUPPORTING_SYSTEMS.md) |
| How do inputs become state, storage and outputs? | [Data-flow and schema map](docs/sale/DATA_FLOW.md) |
| Which decisions are documented or still uncertain? | [Decision register](docs/sale/DECISIONS.csv) |
| How can I run the checks? | [Reproduction notes](docs/sale/TECHNICAL_HANDOVER.md) |
| Which claims have evidence? | [Claims register](docs/sale/CLAIMS.csv) |
| Where are the measured coverage reports? | [Coverage and scope](coverage/README.md), [LCOV](coverage/lcov.info), [Cobertura](coverage/cobertura.xml) |
| What history and local fixes are included? | [Branch history](docs/sale/BRANCH_HISTORY.md), [local capture](docs/sale/LOCAL_WORK_CAPTURE.md) |
| What is excluded or separately licensed? | [Rights and scope](docs/sale/RIGHTS_AND_EXCLUSIONS.md) |

[Watch the historical demo](docs/sale/demo/README.md) or
[run the two historical exercises](evaluation/README.md).

The delivered evidence bundle supplies exact-revision file hashes, a source and
test navigation index, raw check receipts and two verified historical
fail-to-pass examples. The short narrated demo is a historical development
simulation; it is not a field-accuracy measurement or proof of the final commit.

The verified available-code profile passed **1,423 Flutter, 61 Express and 16
sharing tests** at `0752b78`. Measured line coverage was **65.08% for Flutter**
(10,362 / 15,923 lines across 133 instrumented files) and **72.66% for Express**
(303 / 417 across 16). Eight dataset-dependent test files are excluded;
these are scoped measurements, not whole-repository coverage. Each subsequent
[GitHub CI run](https://github.com/Raed2180416/GeoWake-Engineering-Archive/actions)
publishes its own exact-revision coverage artifact and summary.

## Read the history accurately

Historical product, architecture and research documents remain traceable through
[the archive index](docs/archive/README.md). Their old prices, launch plans and
performance aspirations are historical context. New explanations and packaging
changes are dated September 2026; they are not reconstructed old tickets.

Raw recordings from friends' phones are a **separate optional data candidate**.
They are not silently included in the code license. No users, revenue, service
accounts, signing keys or production credentials are offered with this corpus.

## Reproduce the available code checks

```bash
python3 tools/sale/verify.py --profile code --out /tmp/geowake-verification
```

Use Flutter 3.44.6, Node 24.x and Python 3. The code profile explicitly excludes
eight dataset-dependent files, including gates that would otherwise pass on
empty data. Their original source remains present. See the reproduction and
export-scope guides for the separate complete pre-exclusion source receipt.
