#!/usr/bin/env bash
set -uo pipefail
root=${BDS_LAUNCH_ROOT:-/home/lhtian97/Work/bds_poll_failure_reference_20261030}

check_statuses() {
    local pending=0 status record
    for status in results/regression.status results/smoke.status results/strict.status \
        preflight.status pipeline_smoke.status; do
        if [ ! -f "$root/$status" ]; then
            pending=1
            continue
        fi
        record=$(head -n 1 "$root/$status")
        case "$record" in
            "completed exit_code=0 "*) ;;
            started*) pending=1 ;;
            *) printf 'Verification did not pass: %s: %s\n' "$status" "$record" >&2; return 1 ;;
        esac
    done
    if [ "$pending" -eq 1 ]; then return 10; fi
    return 0
}

if [ "${1:-}" = --check-only ]; then
    check_statuses
    exit "$?"
fi
exec 8>"$root/launch.lock"
flock -n 8 || exit 73
test ! -e "$root/compute.status" || exit 78
while true; do
    check_statuses
    rc=$?
    if [ "$rc" -eq 0 ]; then break; fi
    if [ "$rc" -ne 10 ]; then
        printf 'stopped verification_failed utc=%s\n' "$(date -u +%FT%TZ)" > "$root/launcher.status"
        exit "$rc"
    fi
    printf 'waiting_for_verification utc=%s no_time_limit=true\n' "$(date -u +%FT%TZ)" > "$root/launcher.status"
    sleep 30
done
python3 "$root/control/audit_experiment.py" "$root" launch
rc=$?
if [ "$rc" -ne 0 ]; then
    printf 'stopped launch_audit_failed exit_code=%s\n' "$rc" > "$root/launcher.status"
    exit "$rc"
fi
printf 'launching_verified_experiment utc=%s no_time_limit=true\n' "$(date -u +%FT%TZ)" > "$root/launcher.status"
exec bash "$root/control/run_experiment.sh"
