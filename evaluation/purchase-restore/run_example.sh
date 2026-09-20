#!/usr/bin/env bash
set -euo pipefail

# Validate the historical pre-fix task and/or the separate reference in scratch.
mode=both
offline=false
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
log_dir="$script_dir/results/recheck"
flutter_bin="${FLUTTER_BIN:-flutter}"

usage() {
  printf 'Usage: %s [--task|--reference|--both] [--offline] [--log-dir DIR]\n' "$0" >&2
}
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
if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  printf 'Flutter executable not found: %s\n' "$flutter_bin" >&2
  exit 2
fi
mkdir -p -- "$log_dir"
log_dir="$(cd -- "$log_dir" && pwd)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/geowake-restore-XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

run_case() {
  local side="$1" status
  mkdir -p -- "$scratch/$side"
  cp -R -- "$script_dir/$side/lib" "$script_dir/$side/test" "$scratch/$side/"
  cp -- "$script_dir/$side/pubspec.yaml" "$script_dir/$side/pubspec.lock" "$scratch/$side/"
  (
    cd -- "$scratch/$side"
    if [[ "$offline" == true ]]; then
      "$flutter_bin" pub get --offline > "$log_dir/$side-pub-get.log" 2>&1
    else
      "$flutter_bin" pub get > "$log_dir/$side-pub-get.log" 2>&1
    fi
    set +e
    "$flutter_bin" test --no-pub --reporter expanded --concurrency=2 test/monetization/purchase_backend_impl_test.dart > "$log_dir/$side-test.log" 2>&1
    status=$?
    set -e
    printf '%s\n' "$status" > "$log_dir/$side-exit.txt"
  )
  status="$(cat "$log_dir/$side-exit.txt")"
  if [[ "$side" == task ]]; then
    if ((status == 0)) || ! grep -Fq 'Expected: a value less than <1000>' "$log_dir/task-test.log" || ! grep -Fq 'Some tests failed.' "$log_dir/task-test.log" || ! grep -Fq '+2 -1:' "$log_dir/task-test.log"; then
      printf 'Unexpected task result (exit %s); inspect %s\n' "$status" "$log_dir/task-test.log" >&2
      return 1
    fi
    printf 'task: reproduced 1 intended failure and 2 passes; %s\n' "$log_dir/task-test.log"
  else
    if ((status != 0)) || ! grep -Fq '+3: All tests passed!' "$log_dir/reference-test.log"; then
      printf 'Unexpected reference result (exit %s); inspect %s\n' "$status" "$log_dir/reference-test.log" >&2
      return 1
    fi
    printf 'reference: all 3 tests passed; %s\n' "$log_dir/reference-test.log"
  fi
}
case "$mode" in
  task) run_case task ;;
  reference) run_case reference ;;
  both) run_case task; run_case reference ;;
esac
