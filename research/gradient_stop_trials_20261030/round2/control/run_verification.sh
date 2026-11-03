#!/usr/bin/env bash
set -uo pipefail
export BDS_GRADIENT_ROOT=/home/lhtian97/Work/bds_poll_failure_reference_20261030
root=$BDS_GRADIENT_ROOT
export TMPDIR="$root/tmp"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
for stage in "$@"; do
    case "$stage" in
        regression|smoke|strict)
            status="$root/results/$stage.status"
            command="addpath('$root/candidate/tests/tools'); run_bds_mp_verification('$root', '$stage')" ;;
        preflight|pipeline_smoke)
            status="$root/$stage.status"
            command="addpath('$root/control'); gradient_experiment('$stage')" ;;
        *) exit 64 ;;
    esac
    test ! -e "$status" || exit 78
    printf 'started utc=%s no_time_limit=true\n' "$(date -u +%FT%TZ)" > "$status"
    matlab -singleCompThread -batch "$command" > "$root/logs/$stage.log" 2>&1 < /dev/null
    rc=$?
    state=completed
    if [ "$rc" -ne 0 ]; then state=failed; fi
    printf '%s exit_code=%s utc=%s\n' "$state" "$rc" "$(date -u +%FT%TZ)" > "$status"
    if [ "$rc" -ne 0 ]; then exit "$rc"; fi
done
