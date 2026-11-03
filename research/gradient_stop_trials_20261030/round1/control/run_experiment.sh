#!/usr/bin/env bash
set -uo pipefail
export BDS_GRADIENT_ROOT=/home/lhtian97/Work/bds_gradient_stop_20261029
root=$BDS_GRADIENT_ROOT
export TMPDIR="$root/tmp"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
if [ "${1:-}" != --inner ]; then
    exec 9>"$root/experiment.lock"
    flock -n 9 || exit 73
    python3 "$root/control/audit_experiment.py" "$root" launch || exit 78
    if [ -e "$root/compute.status" ]; then
        printf 'Existing run status; inspect before an explicit resume.\n' >&2
        exit 78
    fi
    printf 'started utc=%s deadline_hours=48\n' "$(date -u +%FT%TZ)" > "$root/compute.status"
    timeout --signal=TERM --kill-after=120s 48h bash "$root/control/run_experiment.sh" --inner
    rc=$?
    if [ "$rc" -eq 0 ]; then
        printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$root/compute.status"
    else
        printf 'failed_or_timeout exit_code=%s utc=%s\n' "$rc" "$(date -u +%FT%TZ)" > "$root/compute.status"
    fi
    exit "$rc"
fi
for stage in baseline selection validation report; do
    python3 "$root/control/audit_experiment.py" "$root" > "$root/logs/${stage}_audit.json" || exit 78
    printf 'started utc=%s\n' "$(date -u +%FT%TZ)" > "$root/${stage}.status"
    matlab -singleCompThread -batch \
        "addpath('$root/control'); gradient_experiment('$stage')" \
        > "$root/logs/${stage}.log" 2>&1 < /dev/null
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf 'failed exit_code=%s utc=%s\n' "$rc" "$(date -u +%FT%TZ)" > "$root/${stage}.status"
        exit "$rc"
    fi
    printf 'completed exit_code=0 utc=%s\n' "$(date -u +%FT%TZ)" > "$root/${stage}.status"
done
python3 "$root/control/audit_experiment.py" "$root" > "$root/logs/final_audit.json" || exit 78
