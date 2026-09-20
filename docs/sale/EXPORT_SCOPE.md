# Scope of the prepared code corpus

Prepared 20 September 2026 in a separate clone. Original source/history remains
private and unchanged. The application logic incorporates the latest captured
local fixes and the reproduction repairs in LOCAL_WORK_CAPTURE.md. The export
is a code and engineering-history corpus; data exclusions mean it is not an
identically provisioned copy of the discontinued app.

## Included

Application/backend logic, tests, scripts, original technical history, detailed
feature and data maps, 52 decisions, and two verified historical regression
exercises. Development, release and iOS refs and five archive tags retain their
mapped lineage. ORIGINAL_TO_EXPORT_COMMITS.txt maps all 203 selected original
commit identities to 147 distinct sanitized identities: none maps to zero;
some histories become identical after excluded content is removed. Newly dated
export commits are additional and are not historical development work.

## Exclusions applied across the delivered history

| Material | Treatment |
|---|---|
| Friend-phone sensor files and captured route logs | Outside the code corpus; separate optional candidate only |
| OneUI audio | Removed; three current oscillator-generated tones replace it |
| College presentations, external PDFs, document templates | Withheld; project involvement is not a grant to those documents |
| Mixed OSM/YoMetro catalog, derived station sequences and complete copied catalog in `docs/research/raw/flagged_lines.md` | Generated payloads withheld; public Dart interfaces remain as empty, labeled schema stubs |
| Fifteen scale-fixture pairs using the mixed catalog | Withheld despite synthetic motion; geographic input shares the catalog's boundary |
| Recorded-ride route asset, identifying `DATA_CONTRACT.md` and aligned historical analysis data | Withheld; summarized engineering findings retained |
| Identified credentials and local home-directory strings | Redacted in text and commit messages; scan receipt supplied |
| Installed dependencies, build/cache output, duplicate indexes and annotated code copies | Omitted as redundant artifacts; lockfiles and source tools retained |
| Stash/internal tool refs | Outside selected delivery refs |

The three retained replay triples explicitly describe synthetic IMU/motion.
Their copied geographic headers do not establish the full generation history;
this uncertainty remains disclosed. They are not recorded rides or a
seller-exclusive geographic dataset. OSM inputs/geometry have their own notice
and license scope in THIRD_PARTY_NOTICES.md.

## Verification is specific to its inputs

The 1,466 Flutter / 61 Express / 16 sharing pass receipt names original prepared
source 49a98bc **before data exclusions**. It must not be relabeled as a full
export pass. Empty catalogs can make integrity loops vacuous; route/scale tests
can return early for absent inputs. Export checks report data-dependent cases
separately. The unchanged test source remains available for appropriately
licensed replacement data. The standalone ZUPT and purchase-restore exercises
need none of the withheld geography or recordings.

## Optional recordings

The separately prepared local candidate contains 85 transformed files from 99
unique source blobs across 13 source directories. Directory counts are not
independent ride/device counts. Device identifiers and absolute time were
removed where feasible; trajectories can still identify people. The founder
reports collection from a couple of friends' phones; per-recording training
transfer permission is unestablished. The optional ZIP is not in this repository.

The final external delivery manifest identifies the Git revision, all file
hashes and local/remote equality. Third-party licenses remain separate from
any seller-controlled source grant. No deployment, dataset acquisition or
further product development is included in the transaction.

The full export probe completed and exposed eight failures in five files, all
at the withheld catalog/route boundaries. The code profile excludes those five
files and three additional data gates that can otherwise skip or pass on empty
inputs. Every exclusion and its observed reason is listed in
`tools/sale/dataset-dependent-tests.json`; no original assertion was weakened.

The final curation pass also replaces exact external recording basenames with
opaque fixture identifiers in code, notes and commit messages. Relative-time
research findings remain dated historical analysis, not a transferred raw dataset.
