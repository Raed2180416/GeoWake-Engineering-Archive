# Source navigation

Pinned to source revision `ece03e4ef00ca1580c76e5c1d909c68a23cdc997` before this index was committed.
There are 901 tracked paths in that tree, 4728 lexical symbol
candidates and 1022 resolved static local references. No path
was left unclassified. Broad platform/repository groups preserve uncertain
feature assignments rather than inventing runtime meaning.

- `features.json`: subsystem descriptions and exact source/test/support paths.
- `files.csv`: every tracked path, blob hash, byte size, role, feature and test hints.
- `symbols.csv`: lexical declarations and test labels, with file/line positions.
- `dependencies.csv`: admitted explicit local import/include relationships.
- `test_matches.csv`: direct imports or exact-basename hints, not coverage proof.
- `counts.json`: extraction counts, unmatched tests, placeholders and unresolved edges.

The extractor does not inspect media/data contents, resolve dynamic runtime
behavior, prove ownership or establish code coverage. Evaluation examples copy
small pieces of historical source; they are not additional app features.
Generated-data stubs preserve names only; see `../EXPORT_SCOPE.md`.

Regenerate for any checked-out revision:

```bash
python3 tools/sale/generate_navigation.py --repo . --ref HEAD --output /tmp/geowake-index
```

The final external delivery manifest pins all delivered files at the final
Git revision. Its count includes this subsequently added index. The deep
journey/underground guides identify historical line spans separately.
