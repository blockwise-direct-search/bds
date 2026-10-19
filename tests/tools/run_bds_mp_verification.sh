#!/usr/bin/env bash
# Run inside a new isolated workspace. No set -e: always persist the exit code.
workspace=$1
shift
if [ ! -d "$workspace/candidate/tests/tools" ]; then exit 2; fi
for stage in "$@"; do
    case "${stage%%_retry*}" in
        smoke) limit=1800 ;;
        deliberate_failure) limit=120 ;;
        strict) limit=21600 ;;
        manifest) limit=43200 ;;
        regression) limit=21600 ;;
        *) exit 2 ;;
    esac
    status="$workspace/results/$stage.status"
    if [ -e "$status" ]; then
        printf 'Refusing to overwrite %s\n' "$status" >&2
        exit 2
    fi
    printf 'started pid=%s utc=%s timeout=%s\n' "$$" "$(date -u +%FT%TZ)" "$limit" > "$status.tmp"
    mv "$status.tmp" "$status"
    timeout --kill-after=30s "${limit}s" /usr/local/bin/matlab -batch \
        "addpath('$workspace/candidate/tests/tools'); run_bds_mp_verification('$workspace', '$stage')" \
        > "$workspace/logs/$stage.log" 2>&1 < /dev/null
    result=$?
    state=failed
    if [ "$result" -eq 0 ]; then state=completed; fi
    if [ "$result" -eq 124 ] || [ "$result" -eq 137 ]; then state=timeout; fi
    if [ "$stage" = deliberate_failure ]; then
        if [ "$result" -ne 0 ] && [ "$state" != timeout ] && \
            grep -q 'Solvers differ on DELIBERATE_MISMATCH' "$workspace/logs/$stage.log" && \
            find "$workspace/results/$stage" -name '*.mat' ! -name 'failure.mat' -print -quit | grep -q .; then
            state=expected_failure
        else
            state=failed
        fi
    fi
    printf '%s exit_code=%s utc=%s\n' "$state" "$result" "$(date -u +%FT%TZ)" > "$status.tmp"
    mv "$status.tmp" "$status"
    if [ "$state" != completed ] && [ "$state" != expected_failure ]; then exit 1; fi
done
