#!/usr/bin/env bash
# tsfsb_launch_runner.sh: launch the TSFSB full runner in a detached GNU
# screen session and print the PID, screen name, and log paths. Ported from
# the C02 v14 launch mechanism (screen-based detachment accepted on the
# server; see the TSFSB execution record).
#
# Environment:
#   TSFSB_REPO_ROOT      repository root (default: two levels above this file)
#   TSFSB_ARTIFACT_ROOT  artifact root (required)
#   TSFSB_SCREEN_NAME    screen session name (default: tsfsb_full)
set -euo pipefail

tsfsb_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tsfsb_repo_root="${TSFSB_REPO_ROOT:-$(cd "${tsfsb_script_dir}/../.." && pwd)}"
tsfsb_artifact_root="${TSFSB_ARTIFACT_ROOT:?TSFSB_ARTIFACT_ROOT is required}"
tsfsb_screen_name="${TSFSB_SCREEN_NAME:-tsfsb_full}"
export TSFSB_REPO_ROOT="${tsfsb_repo_root}" TSFSB_ARTIFACT_ROOT="${tsfsb_artifact_root}"

tsfsb_log_dir="${tsfsb_artifact_root}/logs"
mkdir -p "${tsfsb_log_dir}"
tsfsb_screen_log="${tsfsb_log_dir}/screen_${tsfsb_screen_name}.log"

if screen -list | grep -q "[.]${tsfsb_screen_name}[[:space:]]"; then
    printf 'TSFSB_LAUNCH_ERROR screen session %s already exists\n' \
        "${tsfsb_screen_name}" >&2
    exit 1
fi

screen -dmS "${tsfsb_screen_name}" \
    bash -c "\"${tsfsb_script_dir}/tsfsb_full_runner.sh\" \
        >> \"${tsfsb_screen_log}\" 2>&1; \
    printf '%s\n' \$? > \"${tsfsb_log_dir}/screen_${tsfsb_screen_name}.exit\""
sleep 2
tsfsb_screen_pid="$(screen -list | grep "[.]${tsfsb_screen_name}[[:space:]]" \
    | awk -F. '{print $1}' | tr -d '[:space:]')"

printf 'TSFSB_LAUNCH_SCREEN_NAME %s\n' "${tsfsb_screen_name}"
printf 'TSFSB_LAUNCH_SCREEN_PID %s\n' "${tsfsb_screen_pid}"
printf 'TSFSB_LAUNCH_SCREEN_LOG %s\n' "${tsfsb_screen_log}"
printf 'TSFSB_LAUNCH_DRIVER_LOG %s\n' "${tsfsb_log_dir}/full_runner.log"
printf 'TSFSB_LAUNCH_EXIT_MARKER %s\n' \
    "${tsfsb_log_dir}/screen_${tsfsb_screen_name}.exit"
