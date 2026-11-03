#!/usr/bin/env bash
set -uo pipefail
export BDS_GRADIENT_ROOT=/home/lhtian97/Work/bds_gradient_stop_20261029
root=$BDS_GRADIENT_ROOT
export TMPDIR="$root/tmp"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
stage=${1:-preflight}
case "$stage" in preflight|preflight_retry[0-9]*|pipeline_smoke) ;; *) exit 64 ;; esac
test ! -e "$root/$stage.status" || exit 78
printf 'started utc=%s\n' "$(date -u +%FT%TZ)" > "$root/$stage.status"
timeout --signal=TERM --kill-after=120s 2h matlab -singleCompThread -batch \
    "addpath('$root/control'); gradient_experiment('$stage')" \
    > "$root/logs/$stage.log" 2>&1 < /dev/null
rc=$?
state=failed
if [ "$rc" -eq 0 ]; then state=completed; fi
printf '%s exit_code=%s utc=%s\n' "$state" "$rc" "$(date -u +%FT%TZ)" > "$root/$stage.status"
exit "$rc"
