#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$script_dir/../.." && pwd)"
status_dir="$script_dir/testdata/auto_initial_step_size_500n_full_factorial_status"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="$status_dir/full_${timestamp}.log"
exit_file="$status_dir/full_${timestamp}.exit_code"
complete_file="$status_dir/full_${timestamp}.complete"
failed_file="$status_dir/full_${timestamp}.failed"
launch_tmp="$status_dir/latest_launch.txt.tmp.$$"

mkdir -p "$status_dir"
{
    printf 'timestamp=%s\n' "$timestamp"
    printf 'log_file=%s\n' "$log_file"
    printf 'exit_file=%s\n' "$exit_file"
    printf 'complete_file=%s\n' "$complete_file"
    printf 'failed_file=%s\n' "$failed_file"
} > "$launch_tmp"
mv "$launch_tmp" "$status_dir/latest_launch.txt"

cd "$repo_dir" || exit 1
matlab -batch "addpath('$script_dir'); manifest=run_auto_initial_step_size_500n_full_factorial('full'); assert(strcmp(manifest.status,'COMPLETE')); assert(manifest.problem_count == 122); assert(numel(manifest.solver_names) == 17); assert(manifest.max_eval_factor == 500);" \
    > "$log_file" 2>&1
exit_code=$?
printf '%d\n' "$exit_code" > "$exit_file"

if [ "$exit_code" -eq 0 ]; then
    touch "$complete_file"
else
    touch "$failed_file"
fi

exit "$exit_code"
