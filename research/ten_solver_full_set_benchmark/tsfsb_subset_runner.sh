#!/usr/bin/env bash
# tsfsb_subset_runner.sh: run the TSFSB saved-data subset reprofiling in
# MATLAB with a log and an exit marker. New for TSFSB.
#
# Environment:
#   TSFSB_REPO_ROOT      repository root (default: two levels above this file)
#   TSFSB_ARTIFACT_ROOT  artifact root (required)
#   TSFSB_MATLAB         matlab executable (default: matlab)
set -uo pipefail

tsfsb_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tsfsb_repo_root="${TSFSB_REPO_ROOT:-$(cd "${tsfsb_script_dir}/../.." && pwd)}"
tsfsb_artifact_root="${TSFSB_ARTIFACT_ROOT:?TSFSB_ARTIFACT_ROOT is required}"
tsfsb_matlab="${TSFSB_MATLAB:-matlab}"
export TSFSB_ARTIFACT_ROOT

tsfsb_log_dir="${tsfsb_artifact_root}/logs"
mkdir -p "${tsfsb_log_dir}"
tsfsb_log="${tsfsb_log_dir}/subset_runner.log"
tsfsb_exit_marker="${tsfsb_log_dir}/subset_runner.exit"

cd "${tsfsb_artifact_root}"
rm -f "${tsfsb_exit_marker}"
{
    printf 'TSFSB_SUBSET_RUNNER_ATTEMPT_START %s\n' "$(date --iso-8601=seconds)"
    "${tsfsb_matlab}" -batch "\
addpath('${tsfsb_repo_root}/research/ten_solver_full_set_benchmark'); \
tsfsb_subset_runner();"
    tsfsb_status=$?
    printf 'TSFSB_SUBSET_RUNNER_ATTEMPT_END %s %s\n' \
        "$(date --iso-8601=seconds)" "${tsfsb_status}"
} >> "${tsfsb_log}" 2>&1
printf '%s\n' "${tsfsb_status}" > "${tsfsb_exit_marker}"
printf 'TSFSB_SUBSET_RUNNER_EXIT %s log=%s\n' "${tsfsb_status}" "${tsfsb_log}"
exit "${tsfsb_status}"
