#!/usr/bin/env bash
# tsfsb_full_runner.sh: run the ten TSFSB features in spec order, stopping on
# the first failure. Ported from c02_v14_full_runner.sh. Per-feature logs are
# appended (attempt boundaries included) and never overwritten.
#
# Environment:
#   TSFSB_REPO_ROOT      repository root (default: two levels above this file)
#   TSFSB_ARTIFACT_ROOT  artifact root (required)
set -euo pipefail

tsfsb_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tsfsb_repo_root="${TSFSB_REPO_ROOT:-$(cd "${tsfsb_script_dir}/../.." && pwd)}"
tsfsb_artifact_root="${TSFSB_ARTIFACT_ROOT:?TSFSB_ARTIFACT_ROOT is required}"
export TSFSB_REPO_ROOT="${tsfsb_repo_root}" TSFSB_ARTIFACT_ROOT="${tsfsb_artifact_root}"

tsfsb_log_dir="${tsfsb_artifact_root}/logs"
mkdir -p "${tsfsb_log_dir}"
tsfsb_driver_log="${tsfsb_log_dir}/full_runner.log"

tsfsb_features=(
    plain
    noisy_1e-1
    noisy_1e-2
    noisy_1e-3
    noisy_1e-4
    linearly_transformed
    linearly_transformed_noisy_1e-1
    linearly_transformed_noisy_1e-2
    linearly_transformed_noisy_1e-3
    linearly_transformed_noisy_1e-4
)

printf 'TSFSB_FULL_RUNNER_ATTEMPT_START %s\n' \
    "$(date --iso-8601=seconds)" >> "${tsfsb_driver_log}"

for tsfsb_feature in "${tsfsb_features[@]}"; do
    test "$(git -C "${tsfsb_repo_root}" rev-parse HEAD)" = "${TSFSB_EXPECTED_COMMIT:?Frozen commit required}"
    test -z "$(git -C "${tsfsb_repo_root}" status --porcelain)"
    sha256sum --check "${tsfsb_artifact_root}/source_hashes.sha256" >> "${tsfsb_driver_log}" 2>&1
    printf 'TSFSB_FULL_RUNNER_FEATURE_START %s %s\n' \
        "${tsfsb_feature}" "$(date --iso-8601=seconds)" | \
        tee -a "${tsfsb_driver_log}"
    if "${tsfsb_script_dir}/tsfsb_feature_runner.sh" "${tsfsb_feature}" \
            >> "${tsfsb_driver_log}" 2>&1; then
        python3 "${tsfsb_script_dir}/tsfsb_solver_flag_gate.py" \
            "${tsfsb_artifact_root}/evaluations/${tsfsb_feature}/accepted_manifest.json" \
            --output "${tsfsb_artifact_root}/evaluations/${tsfsb_feature}/solver_flag_disposition.json" \
            >> "${tsfsb_driver_log}" 2>&1
        printf 'TSFSB_FULL_RUNNER_FEATURE_ACCEPTED %s\n' "${tsfsb_feature}" | \
            tee -a "${tsfsb_driver_log}"
    else
        tsfsb_status=$?
        printf 'TSFSB_FULL_RUNNER_FEATURE_FAILED %s %s\n' \
            "${tsfsb_feature}" "${tsfsb_status}" | tee -a "${tsfsb_driver_log}"
        exit "${tsfsb_status}"
    fi
done

"${tsfsb_script_dir}/tsfsb_subset_runner.sh" >> "${tsfsb_driver_log}" 2>&1
python3 "${tsfsb_script_dir}/tsfsb_finalize.py" generate "${tsfsb_artifact_root}" \
    --problem-manifest "${tsfsb_artifact_root}/manifest/problem_manifest.json" \
    >> "${tsfsb_driver_log}" 2>&1
printf 'TSFSB_FULL_RUNNER_OK\n' | tee -a "${tsfsb_driver_log}"
