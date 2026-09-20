#!/usr/bin/env bash
# tsfsb_feature_runner.sh: run one TSFSB feature evaluation in MATLAB with a
# per-feature log and an exit marker. Ported from the C02 v14 feature runner
# pattern (c02_v14_full_runner.sh feature loop body).
#
# Usage: tsfsb_feature_runner.sh FEATURE_NAME
# Environment:
#   TSFSB_REPO_ROOT      repository root (default: two levels above this file)
#   TSFSB_ARTIFACT_ROOT  artifact root (required)
#   TSFSB_MATLAB         matlab executable (default: matlab)
set -uo pipefail

tsfsb_feature="${1:?usage: tsfsb_feature_runner.sh FEATURE_NAME}"
tsfsb_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tsfsb_repo_root="${TSFSB_REPO_ROOT:-$(cd "${tsfsb_script_dir}/../.." && pwd)}"
tsfsb_artifact_root="${TSFSB_ARTIFACT_ROOT:?TSFSB_ARTIFACT_ROOT is required}"
tsfsb_matlab="${TSFSB_MATLAB:-matlab}"

tsfsb_log_dir="${tsfsb_artifact_root}/logs"
mkdir -p "${tsfsb_log_dir}"
tsfsb_log="${tsfsb_log_dir}/${tsfsb_feature}.log"
tsfsb_exit_marker="${tsfsb_log_dir}/${tsfsb_feature}.exit"

mkdir -p "${tsfsb_artifact_root}/work/${tsfsb_feature}"
cd "${tsfsb_artifact_root}/work/${tsfsb_feature}"
rm -f "${tsfsb_exit_marker}"
{
    printf 'TSFSB_FEATURE_ATTEMPT_START %s %s\n' \
        "${tsfsb_feature}" "$(date --iso-8601=seconds)"
    TSFSB_FEATURE="${tsfsb_feature}" "${tsfsb_matlab}" -batch "addpath('${tsfsb_repo_root}/research/ten_solver_full_set_benchmark'); tsfsb_options = struct('artifact_root', '${tsfsb_artifact_root}', 'feature_names', {getenv('TSFSB_FEATURE')}); run_tsfsb_benchmark(tsfsb_options); fprintf('TSFSB_FEATURE_MATLAB_OK %s\n', getenv('TSFSB_FEATURE'));"
    tsfsb_status=$?
    printf 'TSFSB_FEATURE_ATTEMPT_END %s %s %s\n' \
        "${tsfsb_feature}" "$(date --iso-8601=seconds)" "${tsfsb_status}"
} >> "${tsfsb_log}" 2>&1
printf '%s\n' "${tsfsb_status}" > "${tsfsb_exit_marker}"
printf 'TSFSB_FEATURE_RUNNER_EXIT %s %s log=%s\n' \
    "${tsfsb_feature}" "${tsfsb_status}" "${tsfsb_log}"
exit "${tsfsb_status}"
