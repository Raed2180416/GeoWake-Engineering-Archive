#!/usr/bin/env python3
"""Inventory a committed revision without embedding source or credential values.

Run after committing a candidate: python3 tools/sale/inventory.py --out /private/path
Dependency license strings are declarations, not a redistribution clearance.
"""
import argparse
import collections
import csv
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CODE_SUFFIXES = {'.dart', '.js', '.ts', '.kt', '.java', '.py', '.c', '.cc', '.cpp', '.h', '.hpp', '.swift', '.m', '.mm'}


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def classification(path):
    if path.startswith(('docs/Sandalsoap-whitefield/', 'route_log_extracted', 'docs/research/raw/')):
        return 'hold: raw recordings or third-party research'
    if path.startswith(('assets/india_metro/', 'assets/osm/', 'assets/ekf_test_routes/')) or path in {
        'lib/all_india_stops.dart', 'lib/data/metro_line_sequences.dart'}:
        return 'hold: mixed-source or ride-derived geography'
    if path.startswith(('test/fixtures/', 'docs/research/underground/plots/')):
        return 'review: simulation/derived-data provenance'
    if path.endswith(('.png', '.jpg', '.jpeg', '.svg', '.ico', '.pdf', '.pptx', '.docx', '.mp4', '.ogg')):
        return 'review: artwork, recording or document rights'
    if path.startswith('assets/ringtones/geowake_'):
        return 'original synthesized tone; see provenance'
    return 'source or documentation; retain dependency notices'


def write_csv(path, rows, fields):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ref', default='HEAD')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    ref = git('rev-parse', '--verify', args.ref + '^{commit}').decode().strip()
    args.out.mkdir(parents=True, exist_ok=True)
    rows, language = [], collections.Counter()
    for item in git('ls-tree', '-rz', '--full-tree', ref).split(b'\0'):
        if not item:
            continue
        meta, path_bytes = item.split(b'\t', 1)
        mode, kind, oid = meta.decode().split()
        path = path_bytes.decode()
        if kind != 'blob':
            continue
        blob = git('cat-file', 'blob', oid)
        suffix = Path(path).suffix
        loc = None
        if suffix in CODE_SUFFIXES:
            loc = sum(bool(line.strip()) for line in blob.decode('utf-8', errors='replace').splitlines())
            language[suffix] += loc
        rows.append(dict(path=path, git_blob=oid, sha256=hashlib.sha256(blob).hexdigest(),
                         bytes=len(blob), nonblank_source_lines=loc, classification=classification(path)))
    write_csv(args.out / 'files.csv', rows, ['path', 'git_blob', 'sha256', 'bytes', 'nonblank_source_lines', 'classification'])
    history = []
    for line in git('log', '--reverse', '--format=%H%x09%aI%x09%an%x09%s', ref).decode().splitlines():
        oid, date, author, subject = line.split('\t', 3)
        history.append(dict(commit=oid, authored_at=date, author=author, subject=subject))
    write_csv(args.out / 'history.csv', history, ['commit', 'authored_at', 'author', 'subject'])
    dependencies = []
    for lock in ['package-lock.json', 'geowake-server/package-lock.json', 'backend/share/package-lock.json']:
        try:
            data = json.loads(git('show', f'{ref}:{lock}'))
        except subprocess.CalledProcessError:
            continue
        for path, pkg in data.get('packages', {}).items():
            if not path:
                continue
            dependencies.append(dict(ecosystem='npm', lockfile=lock, package=path,
                                     version=pkg.get('version', ''), declared_license=pkg.get('license', 'UNKNOWN'),
                                     integrity=pkg.get('integrity', ''), development=pkg.get('dev', False)))
    write_csv(args.out / 'npm-dependencies.csv', dependencies,
              ['ecosystem', 'lockfile', 'package', 'version', 'declared_license', 'integrity', 'development'])
    report = dict(generated_at=datetime.now(timezone.utc).isoformat(), commit=ref,
                  tracked_files=len(rows), tracked_bytes=sum(r['bytes'] for r in rows),
                  reachable_commits=len(history), earliest_commit=history[0] if history else None,
                  latest_commit=history[-1] if history else None,
                  nonblank_source_lines_by_suffix=dict(language),
                  counting_method='Committed recognized code files, including generated/vendored files; excludes JSON/YAML, blanks and data. Not human-authored LOC.',
                  clearance='Inventory only. This is not a legal clearance, valuation, or delivery authorization.')
    (args.out / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'commit': ref, 'files': len(rows), 'commits': len(history), 'output': str(args.out)}))


if __name__ == '__main__':
    main()
