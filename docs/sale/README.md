# GeoWake — buyer review

Prepared 20 September 2026. GeoWake is an Android-first Flutter destination
alarm. The proposed asset is the software and its documented development
history. A licensed underground positioning dataset, a commercial mobility
dataset, revenue, active users, and a staffed company are not included claims.

Start with the [buyer brief](BUYER_BRIEF.md), then the
[technical handover](TECHNICAL_HANDOVER.md). The [claims register](CLAIMS.csv)
separates code evidence, fresh verification, historical reports, and unfinished
work. Read [rights and exclusions](RIGHTS_AND_EXCLUSIONS.md) before requesting
source or history. [Engineering retrospectives](ENGINEERING_RETROSPECTIVES.md)
connect two genuine changes to their code and regression tests.

## Version being reviewed

The preparation branch is `codex/geowake-sale-20260920`, based on
`440e9003cbd3ec7ec78cea0accc56df9cb7d9b2e`. That base has 130 reachable commits
from February 2025 to July 2026. Newly dated preparation commits add buyer
materials and explicit improvements; they do not represent historical work.

The DataVendor estimate used `stable-release-1`, a different branch with
114 commits at the time of its analysis. That estimate is not a price for this
new preparation branch. The main local checkout also contains unpublished
changes, which have not been folded into this candidate or its test claims.

## Review contents

| Item | What it provides |
|---|---|
| Buyer brief | Product, engineering value, offered scope and limitations |
| Technical handover | Setup, local backend, tests, coverage scope and device checks |
| Claims register | Evidence for material statements |
| Rights and exclusions | Dependency/data provenance and items awaiting clearance |
| Engineering retrospectives | Newly written explanations of authentic commits |
| `tools/sale/inventory.py` | Reproducible, commit-specific file hashes and history index |
| `tools/sale/verify.py` | Repeatable verification with dated logs and exit codes |
| Edited demonstration | Separately supplied 112-second historical screen recording |

The demo shows a development simulation feeding a mirrored Android app. Its
new narration explains the screen recording. It does not prove field accuracy,
audible alarm delivery, or correspondence to the offered commit.

## Delivery status

The preparation checkout is useful for local review. It is **not an unrestricted
delivery archive**: mixed-source map data, raw recordings and historical
credentials require the treatment described in the rights document. No
license to those items is implied by this index. A delivery must name its
exact revision, included paths, exclusions, usage rights and acceptance tests.
