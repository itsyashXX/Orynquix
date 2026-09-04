#!/usr/bin/env bash
set -Eeuo pipefail

started_by_test=false
checks=0
failures=0

cleanup() {
    if [[ "$started_by_test" == true ]]; then
        orynquix stop >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT HUP INT TERM

check() {
    local description=$1
    shift
    checks=$((checks + 1))
    if "$@"; then
        printf '✓ %s\n' "$description"
    else
        printf '✗ %s\n' "$description" >&2
        failures=$((failures + 1))
    fi
}

[[ -n "${PREFIX:-}" && -x "$PREFIX/bin/pkg" ]] || {
    printf 'Run this acceptance test from the Termux host shell.\n' >&2
    exit 2
}
command -v orynquix >/dev/null 2>&1 || {
    printf 'The Orynquix CLI is not installed. Run bash install.sh first.\n' >&2
    exit 2
}

printf 'ORYNQUIX V3 DEVICE ACCEPTANCE\n\n'
check 'CLI reports version 0.2.0-alpha' bash -c '[[ "$(orynquix version)" == "Orynquix 0.2.0-alpha" ]]'
check 'System doctor passes' orynquix doctor
check 'Current device information can be detected' orynquix device
check 'Runtime configuration is private' bash -c '[[ "$(stat -c %a "$HOME/.orynquix/config.ini")" == 600 ]]'

if orynquix status >/dev/null 2>&1; then
    printf '! Desktop was already running; this test will preserve it.\n'
else
    if orynquix start; then
        started_by_test=true
    else
        printf '✗ Desktop failed to start. Inspect: orynquix logs vnc\n' >&2
        exit 1
    fi
fi

check 'Managed VNC session reports healthy' orynquix status
check 'Managed session table is available' orynquix sessions
check 'VNC port 5901 accepts a local connection' bash -c 'exec 3<>/dev/tcp/127.0.0.1/5901'

if [[ "$started_by_test" == true ]]; then
    orynquix stop
    started_by_test=false
    if orynquix status >/dev/null 2>&1; then
        printf '✗ Managed session remained active after stop.\n' >&2
        failures=$((failures + 1))
    else
        printf '✓ Managed session stopped cleanly\n'
    fi
fi

printf '\n%d automated device checks completed; %d failed.\n' "$checks" "$failures"
printf 'Manual check still required: connect the VNC viewer to 127.0.0.1:5901 and confirm XFCE renders correctly.\n'
(( failures == 0 ))
