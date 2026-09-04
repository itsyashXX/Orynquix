#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_TMP=$(mktemp -d /tmp/orynquix-web-tests.XXXXXX)
TEST_HOME="$TEST_TMP/home"
mkdir -p "$TEST_HOME"
background_pid=''

cleanup() {
    if [[ "$background_pid" =~ ^[0-9]+$ ]] && kill -0 "$background_pid" 2>/dev/null; then
        kill -TERM "$background_pid" 2>/dev/null || true
        wait "$background_pid" 2>/dev/null || true
    fi
    case "$TEST_TMP" in
        /tmp/orynquix-web-tests.*) find "$TEST_TMP" -depth -delete ;;
    esac
}
trap cleanup EXIT

session_script="$PROJECT_ROOT/rootfs/scripts/web-session.sh"
tests=0
failures=0

check() {
    local description=$1
    shift
    tests=$((tests + 1))
    if "$@"; then
        printf 'ok %d - %s\n' "$tests" "$description"
    else
        printf 'not ok %d - %s\n' "$tests" "$description" >&2
        failures=$((failures + 1))
    fi
}

stopped_output="$TEST_TMP/stopped-output"
if HOME="$TEST_HOME" bash "$session_script" status 6088 5988 >"$stopped_output" 2>&1; then
    stopped_rc=0
else
    stopped_rc=$?
fi
check 'stopped proxy uses the documented non-running exit code' test "$stopped_rc" -eq 3
check 'stopped proxy status is machine readable' grep -Fxq state=stopped "$stopped_output"

injection_marker="$TEST_TMP/port-injection-ran"
payload='6088+$(touch '"$injection_marker"')'
if HOME="$TEST_HOME" bash "$session_script" status "$payload" 5988 >/dev/null 2>&1; then
    injection_rc=0
else
    injection_rc=$?
fi
check 'malicious web port input is rejected' test "$injection_rc" -eq 64
check 'web port validation occurs before arithmetic evaluation' test ! -e "$injection_marker"
check 'matching web and VNC ports are rejected' \
    bash -c '! HOME="$1" bash "$2" status 6088 6088 >/dev/null 2>&1' _ "$TEST_HOME" "$session_script"

state_dir="$TEST_HOME/.local/share/orynquix/state"
mkdir -p "$state_dir"
sleep 30 &
background_pid=$!
cat >"$state_dir/web-session.ini" <<EOF
pid=$background_pid
start_ticks=1
web_port=6088
vnc_port=5988
localhost=true
EOF
chmod 600 "$state_dir/web-session.ini"

stale_output="$TEST_TMP/stale-output"
HOME="$TEST_HOME" bash "$session_script" status 6088 5988 >"$stale_output" 2>&1 || stale_rc=$?
check 'PID identity mismatch is reported as stale' grep -Fxq state=stale "$stale_output"
check 'stale proxy metadata never terminates an unrelated process' kill -0 "$background_pid"

stop_output="$TEST_TMP/stop-output"
HOME="$TEST_HOME" bash "$session_script" stop 6088 5988 >"$stop_output"
check 'stop removes stale proxy metadata' test ! -e "$state_dir/web-session.ini"
check 'stop preserves the unrelated process from stale metadata' kill -0 "$background_pid"

kill -TERM "$background_pid"
wait "$background_pid" 2>/dev/null || true
background_pid=''
python3 -m http.server 6088 --bind 127.0.0.1 >"$TEST_TMP/server.log" 2>&1 &
background_pid=$!
for _ in {1..20}; do
    (exec 3<>/dev/tcp/127.0.0.1/6088) >/dev/null 2>&1 && break
    sleep 0.1
done

occupied_output="$TEST_TMP/occupied-output"
if HOME="$TEST_HOME" bash "$session_script" start 6088 5988 >"$occupied_output" 2>&1; then
    occupied_rc=0
else
    occupied_rc=$?
fi
check 'start refuses a browser port owned by another process' test "$occupied_rc" -eq 4
check 'port refusal explains that ownership was not taken' grep -Fq 'already in use' "$occupied_output"
check 'port refusal never terminates the unrelated listener' kill -0 "$background_pid"

printf '1..%d\n' "$tests"
(( failures == 0 )) || exit 1
printf 'All %d browser-session safety tests passed.\n' "$tests"
