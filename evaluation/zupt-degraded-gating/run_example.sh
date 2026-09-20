#!/usr/bin/env bash
set -euo pipefail

# Run the standalone evaluation task or reference in a disposable copy.
# Original source files under task/ and reference/ are never modified.

usage() {
  printf 'Usage: %s [--task|--reference|--both] [--offline] [--log-dir DIR]\n' "$0" >&2
}

mode=both
offline=false
log_dir="$PWD/evaluation-run-logs"
while (($#)); do
  case "$1" in
    --task) mode=task ;;
    --reference) mode=reference ;;
    --both) mode=both ;;
    --offline) offline=true ;;
    --log-dir)
      shift
      if (($# == 0)); then usage; exit 2; fi
      log_dir="$1" ;;
    *) usage; exit 2 ;;
  esac
  shift
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  printf 'Flutter not found: %s\n' "$flutter_bin" >&2
  exit 2
fi
mkdir -p -- "$log_dir"
log_dir="$(cd -- "$log_dir" && pwd)"
scratch="$(mktemp -d /tmp/geowake-zupt-minimal-XXXXXX)"
trap 'rm -rf -- "$scratch"' EXIT

run_case() {
  local which="$1" status expected
  cp -R -- "$script_dir/$which" "$scratch/$which"
  cd -- "$scratch/$which"
  if [[ "$offline" == true ]]; then
    "$flutter_bin" pub get --offline > "$log_dir/minimal-$which-pub-get.log" 2>&1
  else
    "$flutter_bin" pub get > "$log_dir/minimal-$which-pub-get.log" 2>&1
  fi
  set +e
  "$flutter_bin" test --no-pub --reporter expanded test/core/ekf/zupt_degraded_gating_test.dart > "$log_dir/minimal-$which-test.log" 2>&1
  status=$?
  set -e
  if [[ "$which" == task ]]; then
    expected="$(grep -c 'Expected: false' "$log_dir/minimal-$which-test.log" || true)"
    if ((status == 0)) || [[ "$expected" != 2 ]] || ! grep -Fq 'Some tests failed.' "$log_dir/minimal-$which-test.log" || ! grep -Fq 'smooth cruise + pinned-zero velocity must NOT confirm' "$log_dir/minimal-$which-test.log" || ! grep -Fq 'quiet-but-not-ultra-quiet + stationary hint does NOT' "$log_dir/minimal-$which-test.log"; then
      printf 'Unexpected task result: exit=%s, assertion failures=%s; see %s\n' "$status" "$expected" "$log_dir/minimal-$which-test.log" >&2
      return 1
    fi
    printf 'task: expected fail-to-pass starting point (2 intended failures); %s\n' "$log_dir/minimal-$which-test.log"
  else
    if ((status != 0)) || ! grep -Fq 'All tests passed!' "$log_dir/minimal-$which-test.log" || ! grep -Fq '+5:' "$log_dir/minimal-$which-test.log"; then
      printf 'Reference failed: exit=%s; see %s\n' "$status" "$log_dir/minimal-$which-test.log" >&2
      return 1
    fi
    printf 'reference: all 5 tests passed; %s\n' "$log_dir/minimal-$which-test.log"
  fi
}

case "$mode" in
  task) run_case task ;;
  reference) run_case reference ;;
  both) run_case task; run_case reference ;;
esac
