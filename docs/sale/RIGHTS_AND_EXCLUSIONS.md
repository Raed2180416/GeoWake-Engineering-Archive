# Rights and delivery boundaries

This is a factual inventory prepared on 20 September 2026, not a conclusion
that every item in Git can be licensed. Original files and history are
preserved; current cleanup does not silently erase historical inclusions.

| Material | Evidence | Delivery treatment |
|---|---|---|
| Seller-controlled source | Git history, original project files; seller reports solo development | Specify exact code paths and revision; do not infer ownership from author counts alone |
| AI assistance | Copilot author entries and Claude coauthor trailers | Disclose AI assistance; do not represent an exclusively human-authored archive |
| Other named contributor | Four Anirudha commits add college presentation material | Historical presentation/paper material excluded pending its own clearance; no assumption that paper coauthorship establishes code ownership |
| Original new alarm tones | `tools/sale/generate_alarm_tones.py`; oscillator-only generation | Three WAVs in current Flutter bundle; method documented in `assets/ringtones/PROVENANCE.md` |
| Earlier One UI audio | Eleven recordings in earlier revisions, no grant found | Removed from current preparation tree; exclude from delivered history unless permission is documented |
| OpenStreetMap-derived data | `assets/india_metro/india_metro_osm_stations.meta.json` identifies ODbL | Preserve source and attribution; license obligations remain separate from proprietary code |
| YoMetro / mixed map data | Dataset source tags and `scripts/scrape_yometro.py` | Hold mixed dataset and derived station lists pending a documented reuse basis or independently sourced replacement |
| Raw ride recordings | `docs/Sandalsoap-whitefield/`, including coordinates and device metadata | Exclude from default delivery pending provenance and subject/transfer rights |
| Ride-derived route geometry | `assets/ekf_test_routes/`, `route_log_extracted.json` | Hold pending provenance review; useful local research is not a cleared commercial dataset |
| Synthetic replay and scale data | JSON flags `synthetic: true` | Identify as synthetic. Geographic inputs may still carry upstream rights; review separately |
| App icon, screenshots, documents | Files present; creation records incomplete | Preserve and inventory; no unqualified rights representation |
| Package dependencies | npm lockfiles, Flutter package notices, native build inputs | Third-party licenses continue to apply; include notices for delivered components |
| Historical credentials | Local history scan returned credential-pattern findings | Original history must not be sent. Sanitize a separate export, rescan it, document mapping, and establish rotation/revocation status |

[OpenStreetMap's copyright page](https://www.openstreetmap.org/copyright)
explains its attribution and database licensing. A proprietary code license
does not turn third-party geographic data into exclusively owned data.

## Project licensing ambiguity

The original root npm manifest declares `ISC`; the share backend declares
`UNLICENSED`; no project-wide license file was found. Preserve these facts in
the review. A newly written notice cannot undo an earlier license grant, and
repository privacy is not proof that every component has always been private.
The public marketing site is distinct from the private GitHub repository.

## History and reconstructed context

130 reachable baseline commits contain 119 Raed author entries, seven Copilot
bot entries and four Anirudha entries. These are Git metadata counts, not a
headcount. Current GitHub metadata showed no issues and one closed, unmerged
pull request. A commit message mentioning another PR does not establish that
the PR record is available.

New retrospectives may explain real commits and test behavior. They must remain
dated 20 September 2026 or later, with their supporting commits identified.
Do not backdate tickets, invent code reviews or chat, relabel generated data as
recorded rides, or use a reconstructed work item as an original customer request.

## Minimum delivery record

Record the approved revision and path manifest, retained notices, data
exclusions, secret-scan result, any sanitized-history mapping and who may use
the delivered material. Keep negotiation notes, private correspondence,
account exports, credentials and payment details outside the code package.
