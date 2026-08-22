#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 2 ]; then
    printf 'Usage: %s SOURCE_DATA OUTPUT_ROOT\n' "$0" >&2
    exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
source_data="$1"
output_root="$2"
status_dir="$output_root/status"
log_file="$status_dir/pairwise_generation.log"
exit_file="$status_dir/pairwise_generation.exit_code"
complete_file="$status_dir/pairwise_generation.complete"
failed_file="$status_dir/pairwise_generation.failed"

mkdir -p "$status_dir"
matlab_command="addpath('$script_dir');"
matlab_command+="manifest=generate_pairwise_baseline_results('$source_data','$output_root');"
matlab_command+="assert(manifest.problem_count == 122);"
matlab_command+="assert(isequal(manifest.analysis_horizons,[200,500]));"
matlab_command+="assert(isequal(size(manifest.pairwise_scores_200),[16,2]));"
matlab_command+="assert(isequal(size(manifest.pairwise_scores_500),[16,2]));"
matlab_command+="assert(exist(fullfile('$output_root',manifest.figure_200),'file')==2);"
matlab_command+="assert(exist(fullfile('$output_root',manifest.figure_500),'file')==2);"
matlab -batch "$matlab_command" \
    > "$log_file" 2>&1
exit_code=$?
printf '%d\n' "$exit_code" > "$exit_file"

if [ "$exit_code" -eq 0 ]; then
    touch "$complete_file"
else
    touch "$failed_file"
fi

exit "$exit_code"
