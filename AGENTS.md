# GeoWake engineering archive — agent orientation

This repository is a prepared AI-training and software-engineering-evaluation
corpus. Start with README.md and docs/sale/README.md. It is not a deployment
handover or a commitment to finish product development.

The application, Android plugin, Express backend and tests retain their
engineering context. Mixed metro catalogs and recording-derived assets are
withheld; their interfaces and exclusions are documented in
`docs/sale/EXPORT_SCOPE.md`.

Run the available-code checks with:

```bash
python3 tools/sale/verify.py --profile code --out /tmp/geowake-verification
```

Use Flutter 3.44.6, Node 24.x and Python 3. Eight dataset-dependent test files
are explicitly excluded by this profile; `--profile full` attempts the original
suite and requires compatible, properly licensed missing inputs. Read
`docs/sale/VERIFICATION.md` before interpreting pass counts or coverage.

Preserve original source and test assertions. Keep new annotations dated and
separate from historical evidence. Use the commit lookup described in the buyer
index when following original commit IDs, because sanitization changed hashes.

The original design invariants (free core alarm, consent default off,
premium failures isolated from core alarms, and no snooze) remain useful
engineering context. “Never late” is a conditional model/simulation objective,
not a demonstrated unconditional physical-device guarantee. Original agent
instructions are preserved in `docs/archive/AGENTS-before-corpus.md`.
