#!/usr/bin/env bash
set -uo pipefail
export BDS_THRESHOLD_ROOT=/home/lhtian97/Work/bds_gradient_threshold_20261030
root=$BDS_THRESHOLD_ROOT
export TMPDIR="$root/tmp"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
exec 9>"$root/run.lock"
flock -n 9 || exit 73
test ! -e "$root/run.status" || exit 78
printf 'started utc=%s no_time_limit=true\n' "$(date -u +%FT%TZ)" > "$root/run.status"
for stage in unit regression smoke strict preflight seed1 seed2 report; do
    python3 "$root/control/prepare.py" "$root" audit > "$root/logs/${stage}_audit.json"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'failed audit=%s exit_code=%s\n' "$stage" "$rc" > "$root/run.status"
        exit "$rc"
    fi
    case "$stage" in
        regression|smoke|strict)
            command="addpath('$root/candidate/tests/tools'); run_bds_mp_verification('$root', '$stage')" ;;
        *) command="addpath('$root/control'); threshold_experiment('$stage')" ;;
    esac
    printf 'started utc=%s\n' "$(date -u +%FT%TZ)" > "$root/$stage.status"
    matlab -singleCompThread -batch "$command" > "$root/logs/$stage.log" 2>&1 < /dev/null
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'failed exit_code=%s utc=%s\n' "$rc" "$(date -u +%FT%TZ)" > "$root/$stage.status"
        printf 'failed stage=%s exit_code=%s\n' "$stage" "$rc" > "$root/run.status"
        exit "$rc"
    fi
    printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$root/$stage.status"
done
python3 "$root/control/prepare.py" "$root" audit > "$root/logs/final_audit.json"
rc=$?
if [ "$rc" -ne 0 ]; then
    printf 'failed final_audit exit_code=%s\n' "$rc" > "$root/run.status"
    exit "$rc"
fi
printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$root/run.status"
