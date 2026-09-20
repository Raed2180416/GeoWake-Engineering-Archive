#!/usr/bin/env python3
"""Run buyer checks and keep raw logs outside the repository.

Example: python3 tools/sale/verify.py --out /tmp/geowake-verification
Requires Flutter 3.44.6, Node/npm and Python 3. No live credentials are needed.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def git_metadata(root):
    """Source-only ZIPs have no Git metadata; never borrow a parent repo identity."""
    result = {'revision': None, 'working_tree_status': None, 'source_mode': 'source-archive'}
    if not shutil.which('git'):
        return result
    top = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=root,
                         text=True, capture_output=True)
    if top.returncode or Path(top.stdout.strip()).resolve() != root.resolve():
        return result
    result.update(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
                  working_tree_status=subprocess.check_output(['git', 'status', '--porcelain=v1'], cwd=root, text=True),
                  source_mode='git-checkout')
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--flutter', default='flutter')
    p.add_argument('--concurrency', type=int, default=2, help='Flutter test workers; keep resource use predictable')
    p.add_argument('--profile', choices=['full', 'code'], default='full',
                   help='code excludes explicitly listed dataset-dependent files; full retains all original tests')
    p.add_argument('--skip-install', action='store_true', help='Use already resolved dependencies')
    args = p.parse_args()
    out = args.out.resolve()
    if out == ROOT or ROOT in out.parents:
        p.error('Write verification output outside the source tree.')
    flutter = shutil.which(args.flutter)
    if not flutter or not shutil.which('npm'):
        p.error('Flutter and npm must be available; use --flutter for an absolute SDK path.')
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, GOOGLE_MAPS_API_KEY='test-maps-key',
               JWT_SECRET='test-jwt-secret-at-least-32-characters-long',
               APP_BUNDLE_ID='com.geowake.app', NODE_ENV='test')
    checks = [('toolchain', [flutter, '--version'], ROOT)]
    if not args.skip_install:
        checks += [('flutter-dependencies', [flutter, 'pub', 'get'], ROOT),
                   ('node-dependencies', ['npm', 'ci', '--ignore-scripts', '--no-audit'], ROOT / 'geowake-server')]
    exclusions = json.loads((ROOT / 'tools/sale/dataset-dependent-tests.json').read_text()) if args.profile == 'code' else {}
    flutter_selection = [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'test').rglob('*_test.dart'))
                         if str(p.relative_to(ROOT)) not in exclusions] if exclusions else []
    checks += [('analyze', [flutter, 'analyze', 'lib/', '--no-fatal-infos'], ROOT),
               ('flutter-tests', [flutter, 'test', '--coverage', '--concurrency', str(args.concurrency), '--reporter', 'json', *flutter_selection], ROOT),
               ('backend-tests', ['npm', 'test', '--', '--runInBand', '--coverage', '--json',
                                  '--outputFile=' + str(out / 'backend-tests.json')], ROOT / 'geowake-server'),
               ('share-tests', ['npm', 'test'], ROOT / 'backend/share')]
    report = {'started_at': datetime.now(timezone.utc).isoformat(),
              **git_metadata(ROOT),
              'verification_script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'profile': args.profile, 'excluded_test_files': exclusions,
              'checks': [], 'scope': 'Headless/local checks; no field, OEM, real-store, or live-service validation.'}
    for name, command, cwd in checks:
        start = time.monotonic()
        log = out / (name + '.log')
        with log.open('wb') as stream:
            result = subprocess.run(command, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        item = dict(name=name, command=command, cwd=str(cwd.relative_to(ROOT)), exit_code=result.returncode,
                    seconds=round(time.monotonic() - start, 2), log=log.name,
                    sha256=hashlib.sha256(log.read_bytes()).hexdigest())
        report['checks'].append(item)
        (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
        print(f'{name}: {"PASS" if result.returncode == 0 else "FAIL"}', flush=True)
        if result.returncode:
            return 1
    for path in ['coverage/lcov.info', 'geowake-server/coverage/lcov.info']:
        source = ROOT / path
        if source.exists():
            shutil.copy2(source, out / path.replace('/', '-'))
    report['finished_at'] = datetime.now(timezone.utc).isoformat()
    (out / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
