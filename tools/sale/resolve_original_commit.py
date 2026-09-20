#!/usr/bin/env python3
"""Translate an original commit ID or unique prefix into delivered Git history."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('revision', help='Full historical commit ID or unique hex prefix (at least seven characters)')
a = p.parse_args()
if len(a.revision) < 7 or any(c not in '0123456789abcdefABCDEF' for c in a.revision):
    p.error('Use a full commit ID or a hexadecimal prefix of at least seven characters.')
mapping = {}
for name in ['ORIGINAL_TO_EXPORT_COMMITS.txt', 'PRE_EXPORT_TO_DELIVERY_COMMITS.txt']:
    f = ROOT / 'docs/sale' / name
    if f.exists():
        for line in f.read_text().splitlines():
            parts = line.split()
            if len(parts) == 2 and len(parts[0]) == 40 and len(parts[1]) == 40:
                mapping[parts[0]] = parts[1]
matches = [k for k in mapping if k.startswith(a.revision.lower())]
if len(matches) != 1:
    p.error('No unique original commit match; use a longer ID or inspect the delivered maps.')
resolved = mapping[matches[0]]
seen = set()
while resolved in mapping and resolved not in seen and mapping[resolved] != resolved:
    seen.add(resolved)
    resolved = mapping[resolved]
if resolved == '0' * 40:
    p.error('The requested commit is explicitly absent from delivered history.')
r = subprocess.run(['git', 'cat-file', '-e', resolved + '^{commit}'], cwd=ROOT, capture_output=True)
if r.returncode:
    p.error('Mapped object is unavailable; use the supplied Git repository or bundle rather than the source-only ZIP.')
print(resolved)
