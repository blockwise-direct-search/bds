#!/usr/bin/env bash
set -uo pipefail
export BDS_GRADIENT_ROOT=/home/lhtian97/Work/bds_poll_failure_reference_20261030
root=$BDS_GRADIENT_ROOT
export TMPDIR="$root/tmp"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
exec 9>"$root/experiment.lock"
flock -n 9 || exit 73
python3 "$root/control/audit_experiment.py" "$root" launch || exit 78
test ! -e "$root/compute.status" || exit 78
printf 'started utc=%s no_time_limit=true\n' "$(date -u +%FT%TZ)" > "$root/compute.status"
for stage in baseline selection validation baseline_fresh validation_fresh evaluation_fresh report; do
    python3 "$root/control/audit_experiment.py" "$root" > "$root/logs/${stage}_audit.json"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'failed audit_stage=%s exit_code=%s utc=%s\n' "$stage" "$rc" "$(date -u +%FT%TZ)" > "$root/compute.status"
        exit "$rc"
    fi
    printf 'started utc=%s\n' "$(date -u +%FT%TZ)" > "$root/$stage.status"
    matlab -singleCompThread -batch "addpath('$root/control'); gradient_experiment('$stage')" \
        > "$root/logs/$stage.log" 2>&1 < /dev/null
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'failed exit_code=%s utc=%s\n' "$rc" "$(date -u +%FT%TZ)" > "$root/$stage.status"
        printf 'failed stage=%s exit_code=%s utc=%s\n' "$stage" "$rc" "$(date -u +%FT%TZ)" > "$root/compute.status"
        exit "$rc"
    fi
    printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$root/$stage.status"
done
python3 "$root/control/audit_experiment.py" "$root" > "$root/logs/final_audit.json"
rc=$?
if [ "$rc" -ne 0 ]; then
    printf 'failed final_audit exit_code=%s\n' "$rc" > "$root/compute.status"
    exit "$rc"
fi
printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$root/compute.status"
