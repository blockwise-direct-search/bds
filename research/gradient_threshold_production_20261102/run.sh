#!/usr/bin/env bash
# Explicit gates only. No benchmark, historical-output changes, or time limit.
set -uo pipefail
workspace=/home/lhtian97/Work/bds_dual_gradient_production_20261102
for stage in "$@"; do
    status="$workspace/results/$stage.status"
    test ! -e "$status" || exit 73
    printf 'started utc=%s\n' "$(date -u +%FT%TZ)" > "$status"
    matlab -singleCompThread -batch \
        "addpath('$workspace/control'); run_production_verification('$workspace', '$stage')" \
        > "$workspace/logs/$stage.log" 2>&1 < /dev/null
    result=$?
    if [ "$result" -ne 0 ]; then
        printf 'failed exit_code=%s utc=%s\n' "$result" "$(date -u +%FT%TZ)" > "$status"
        exit "$result"
    fi
    printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$status"
done
