#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$script_dir/../../.." && pwd)"
cd "$repo_dir"
status_dir="$script_dir/testdata/gradient_stop_final_comparison_status"
mkdir -p "$status_dir"
stamp=$(date +%Y%m%d_%H%M%S)
log_file="$status_dir/full_${stamp}.log"
exit_file="$status_dir/full_${stamp}.exit"

set +e
matlab -batch "addpath('$script_dir'); run_gradient_stop_final_comparison" \
    >"$log_file" 2>&1
exit_code=$?
set -e
printf '%s\n' "$exit_code" >"$exit_file"
exit "$exit_code"
