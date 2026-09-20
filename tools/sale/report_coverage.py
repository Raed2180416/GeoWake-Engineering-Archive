#!/usr/bin/env python3
"""Publish scoped coverage from a successful verify.py receipt; no test rerun."""
import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


def read_lcov(path, prefix):
    records, normalized = [], []
    current = None
    for line in path.read_text().splitlines():
        if line.startswith('SF:'):
            relative = Path(prefix) / line[3:]
            if relative.is_absolute() or '..' in relative.parts:
                raise ValueError(f'Non-relative coverage source: {relative}')
            source = ROOT / relative
            if not source.is_file():
                raise ValueError(f'Coverage source is absent: {relative}')
            current = {'path': relative.as_posix(), 'lines': {},
                       'sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
            line = 'SF:' + current['path']
        elif line.startswith('DA:'):
            number, hits, *_ = line[3:].split(',')
            current['lines'][int(number)] = int(hits)
        elif line.startswith(('LF:', 'LH:')):
            current[line[:2]] = int(line[3:])
        elif line == 'end_of_record':
            if current is None:
                raise ValueError('LCOV record has no source')
            measured = len(current['lines'])
            covered = sum(hits > 0 for hits in current['lines'].values())
            if current.get('LF') != measured or current.get('LH') != covered:
                raise ValueError(f'LCOV totals disagree: {current["path"]}')
            records.append(current)
            current = None
        normalized.append(line)
    if current is not None or not records:
        raise ValueError('Incomplete or empty LCOV report')
    return records, '\n'.join(normalized) + '\n'


def counts(records):
    total = sum(len(r['lines']) for r in records)
    covered = sum(h > 0 for r in records for h in r['lines'].values())
    return {'total': total, 'covered': covered, 'skipped': 0,
            'pct': round(100 * covered / total, 2) if total else None}


def publish(verification_dir, out, ci_url=None, job_summary=None):
    receipt = json.loads((verification_dir / 'verification.json').read_text())
    if not receipt.get('finished_at') or any(c['exit_code'] for c in receipt['checks']):
        raise ValueError('Coverage requires a completed, successful verification receipt')
    projects, all_records, combined = {}, [], ''
    for name, filename, prefix in [
        ('flutter', 'coverage-lcov.info', ''),
        ('express', 'geowake-server-coverage-lcov.info', 'geowake-server'),
    ]:
        path = verification_dir / filename
        records, lcov = read_lcov(path, prefix)
        projects[name] = {'lines': counts(records), 'instrumented_files': len(records),
                          'input_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        all_records.extend(records)
        combined += lcov
    if len({r['path'] for r in all_records}) != len(all_records):
        raise ValueError('Duplicate source path across coverage reports')
    summary = {'total': {'lines': counts(all_records)}, 'projects': projects,
               'source_revision': receipt['revision'], 'ci_url': ci_url,
               'measured_at': receipt['finished_at'], 'profile': receipt['profile'],
               'excluded_test_files': receipt['excluded_test_files'],
               'scope': 'Line coverage over instrumented Flutter and Express files only. '
                        'Sharing coverage is not measured. This is not whole-repository coverage.',
               'source_file_sha256': {r['path']: r['sha256'] for r in all_records}}
    out.mkdir(parents=True, exist_ok=True)
    (out / 'lcov.info').write_text(combined)
    (out / 'coverage-summary.json').write_text(json.dumps(summary, indent=2) + '\n')

    # Cobertura's branch fields describe no branch instrumentation in this
    # line-only conversion; original function/branch records remain in LCOV.
    totals = summary['total']['lines']
    root = ET.Element('coverage', {'line-rate': str(totals['covered'] / totals['total']),
        'branch-rate': '0', 'lines-covered': str(totals['covered']),
        'lines-valid': str(totals['total']), 'branches-covered': '0',
        'branches-valid': '0', 'version': 'geowake-line-coverage-1'})
    ET.SubElement(ET.SubElement(root, 'sources'), 'source').text = '.'
    packages = ET.SubElement(root, 'packages')
    for name in projects:
        records = [r for r in all_records if r['path'].startswith(
            'lib/' if name == 'flutter' else 'geowake-server/')]
        c = counts(records)
        package = ET.SubElement(packages, 'package', {'name': name,
            'line-rate': str(c['covered'] / c['total']), 'branch-rate': '0'})
        classes = ET.SubElement(package, 'classes')
        for record in records:
            c = counts([record])
            cls = ET.SubElement(classes, 'class', {'name': record['path'],
                'filename': record['path'], 'line-rate': str(c['covered'] / c['total']),
                'branch-rate': '0'})
            ET.SubElement(cls, 'methods')
            lines = ET.SubElement(cls, 'lines')
            for number, hits in sorted(record['lines'].items()):
                ET.SubElement(lines, 'line', {'number': str(number), 'hits': str(hits), 'branch': 'false'})
    ET.indent(root)
    ET.ElementTree(root).write(out / 'cobertura.xml', encoding='utf-8', xml_declaration=True)

    markdown = ['# Measured line coverage', '',
        f'Source revision: `{receipt["revision"]}`. Profile: `{receipt["profile"]}`.', '',
        '| Component | Covered / measured lines | Line coverage | Instrumented files |',
        '|---|---:|---:|---:|']
    for name, data in projects.items():
        c = data['lines']
        markdown.append(f'| {name} | {c["covered"]} / {c["total"]} | {c["pct"]:.2f}% | {data["instrumented_files"]} |')
    markdown.extend(['', f'{len(receipt["excluded_test_files"])} dataset-dependent test files are explicitly excluded.',
        summary['scope'], 'Cobertura contains line coverage only; see LCOV for the original branch/function records.',
        '', f'CI receipt: {ci_url}' if ci_url else 'See the verification.json receipt beside this report.', ''])
    text = '\n'.join(markdown)
    (out / 'SUMMARY.md').write_text(text)
    if job_summary:
        with job_summary.open('a') as stream:
            stream.write(text)
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verification-dir', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--ci-url')
    parser.add_argument('--job-summary', type=Path)
    args = parser.parse_args()
    report = publish(args.verification_dir, args.out, args.ci_url, args.job_summary)
    print(json.dumps({k: v['lines'] for k, v in report['projects'].items()}))
