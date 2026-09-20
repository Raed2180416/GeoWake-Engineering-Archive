# Existing local work captured for the archive

Captured 20 September 2026 from the pre-existing working checkout based on
`440e9003cbd3ec7ec78cea0accc56df9cb7d9b2e`. The founder asked for the listed
repository to include the latest local fixes. This preparation records 119
modified tracked files and 24 additional source, test and design files. It
does not backdate them or claim they were part of the older release branch.

The original checkout was read without modification. The binary patch and
file hashes are privately preserved. Local IDE configuration, tool settings
and generated build caches were retained in the original checkout and kept
out of the code corpus. Existing packaging changes (original generated alarm
tones and buyer documentation) were retained. The sole three-way conflict
was wording in an API-endpoint comment; the existing local wording was used.

The capture includes existing recovery/handshake logic, threshold validation,
route-endpoint and trusted-station handling, entitlement and billing work,
share-link changes, related regressions, and a maps-provider parity contract.
These are archived as existing development work, without assuming that every
change is complete or production-validated. New verification is recorded
separately and must name this revision; earlier baseline results are not
relabelled as results for this capture.

The first check of the captured work found a missing `hintIndex` parameter in
the private route-snapping helper. Preparation wired the existing public hint
through that helper and retained a full-search escape when a hint is stale.
An unnecessary null assertion was also removed from route geometry. These
small reproduction fixes are separately dated changes; the pre-fix capture
remains in history for comparison.

The full captured suite then exposed two missing test type/import references,
six deviation fixtures still using the previous 15 m base threshold, a logger
flush fixture without writable storage, and a generic metro color incorrectly
fuzzy-matching a city-qualified name. Preparation repairs qualify the types,
move the intended off-route stimulus to 40 m (above the current 37.5 m
threshold at 5 m/s), provide temporary storage and verify the written CSV,
and preserve the city-neutral fallback. The existing before-repair commit
and failing log remain available. No threshold or underground model was tuned
for the sale.
