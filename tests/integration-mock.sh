#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_TMP=$(mktemp -d /tmp/orynquix-integration.XXXXXX)
TEST_HOME="$TEST_TMP/home"
TEST_PREFIX="$TEST_TMP/prefix"
MOCK_STATE="$TEST_TMP/mock-state"
MOCK_BIN="$TEST_PREFIX/bin"
mkdir -p "$TEST_HOME" "$MOCK_STATE" "$MOCK_BIN"

cleanup() {
    case "$TEST_TMP" in
        /tmp/orynquix-integration.*) find "$TEST_TMP" -depth -delete ;;
    esac
}
trap cleanup EXIT

write_mock() {
    local name=$1
    shift
    printf '%s\n' "$@" >"$MOCK_BIN/$name"
    chmod +x "$MOCK_BIN/$name"
}

write_mock pkg '#!/usr/bin/env bash' \
    'printf "Get:1 mock package line that must stay in the log\n"' \
    'exit 0'

write_mock curl '#!/usr/bin/env bash' 'exit 0'
write_mock getent '#!/usr/bin/env bash' 'printf "127.0.0.1 STREAM github.com\n"' 'exit 0'
write_mock getprop '#!/usr/bin/env bash' \
    'case "${1-}" in' \
    '  ro.product.manufacturer) printf "ExampleCorp\n" ;;' \
    '  ro.product.model) printf "Test Phone\n" ;;' \
    '  ro.build.version.release) printf "14\n" ;;' \
    '  ro.build.version.sdk) printf "34\n" ;;' \
    '  persist.sys.timezone) printf "UTC\n" ;;' \
    'esac'
write_mock termux-info '#!/usr/bin/env bash' 'printf "TERMUX_VERSION=0.119.0\n"'

write_mock proot-distro '#!/usr/bin/env bash' \
    'set -Eeuo pipefail' \
    'state=${MOCK_PROOT_STATE:?}' \
    'case "${1-}" in' \
    '  --version) printf "proot-distro mock 1.0\n"; exit 0 ;;' \
    '  list) printf "No containers installed.\n"; exit 0 ;;' \
    '  install)' \
    '    if [[ "${2-}" == --help ]]; then printf "usage: proot-distro install [--name NAME] IMAGE from OCI registry\n"; exit 0; fi' \
    '    [[ "${2-}" == ubuntu:24.04 ]] || exit 66' \
    '    printf "%s\n" "${2-}" >"$state/installed-image"' \
    '    touch "$state/installed"; exit 0 ;;' \
    '  login) shift ;;' \
    '  *) exit 64 ;;' \
    'esac' \
    'login_user=' \
    'while [[ "${1-}" == --* ]]; do' \
    '  case "$1" in' \
    '    --user) login_user=$2; shift 2 ;;' \
    '    --shared-tmp) shift ;;' \
    '    *) exit 64 ;;' \
    '  esac' \
    'done' \
    'distribution=${1-}; shift || true' \
    '[[ "$distribution" == ubuntu ]] || exit 65' \
    '[[ "${1-}" == -- ]] && shift' \
    'command_path=${1-}; shift || true' \
    'case "$command_path" in' \
    '  /usr/bin/test|test)' \
    '    case "${1-}:${2-}" in' \
    '      -r:/etc/os-release) [[ -f "$state/installed" ]] ;;' \
    '      -r:/etc/orynquix-release) [[ -f "$state/marker" ]] ;;' \
    '      -d:/home/*) [[ -f "$state/user" ]] ;;' \
    '      -x:/usr/local/libexec/orynquix/vnc-session) [[ -f "$state/vnc-runtime" ]] ;;' \
    '      -x:/usr/local/libexec/orynquix/web-session) [[ -f "$state/web-runtime" ]] ;;' \
    '      -x:/usr/local/libexec/orynquix/apply-appearance) [[ -f "$state/appearance-runtime" ]] ;;' \
    '      -x:/usr/local/libexec/orynquix/start-xfce) [[ -f "$state/xfce-runtime" ]] ;;' \
    '      -x:/home/*/xstartup) [[ -f "$state/xstartup" ]] ;;' \
    '      -x:/home/*/orynquix-terminal.desktop) [[ -f "$state/terminal-launcher" ]] ;;' \
    '      -x:/home/*/orynquix-files.desktop) [[ -f "$state/files-launcher" ]] ;;' \
    '      -s:/home/*/vnc.ini) [[ -f "$state/vnc-config" ]] ;;' \
    '      -s:/home/*/passwd) [[ -f "$state/vnc-password" ]] ;;' \
    '      -s:/usr/share/backgrounds/orynquix/orynquix-default.png) [[ -f "$state/wallpaper" ]] ;;' \
    '      *) exit 0 ;;' \
    '    esac ;;' \
    '  /bin/cat)' \
    '    cat <<EOF' \
    'ID=ubuntu' \
    'VERSION_ID="24.04"' \
    'PRETTY_NAME="Ubuntu 24.04 LTS"' \
    'VERSION_CODENAME=noble' \
    'EOF' \
    '    ;;' \
    '  /usr/bin/id) [[ -f "$state/user" ]] ;;' \
    '  /usr/sbin/useradd) printf "%s\n" "${*: -1}" >"$state/user" ;;' \
    '  /usr/bin/stat)' \
    '    format=${2-}' \
    '    if [[ "$format" == %a ]]; then printf "600\n"; else cat "$state/user"; fi ;;' \
    '  /usr/bin/tee)' \
    '    destination=${1-}' \
    '    content=$(cat)' \
    '    [[ "$destination" == /etc/orynquix-release ]] && printf "%s\n" "$content" >"$state/marker"' \
    '    printf "%s\n" "$content" ;;' \
    '  /bin/grep)' \
    '    [[ "${3-}" == /etc/orynquix-release ]] && grep "${1-}" "${2-}" "$state/marker" ;;' \
    '  /usr/sbin/chpasswd) cat >/dev/null; touch "$state/password" ;;' \
    '  /usr/sbin/visudo|/usr/sbin/usermod|/usr/sbin/locale-gen|/usr/sbin/update-locale)' \
    '    exit 0 ;;' \
    '  /usr/bin/apt-get)' \
    '    printf "Fetched mock packages that must stay in the log\n"; exit 0 ;;' \
    '  /usr/bin/dpkg-query)' \
    '    printf "installed\n"; exit 0 ;;' \
    '  /bin/sh)' \
    '    script=${2-}' \
    '    marker=${3-}' \
    '    if [[ "$marker" == orynquix-atomic ]]; then' \
    '      target=${4-}; cat >/dev/null' \
    '      case "$target" in' \
    '        /usr/local/libexec/orynquix/vnc-session) touch "$state/vnc-runtime" ;;' \
    '        /usr/local/libexec/orynquix/web-session) touch "$state/web-runtime" ;;' \
    '        /usr/local/libexec/orynquix/apply-appearance) touch "$state/appearance-runtime" ;;' \
    '        /usr/local/libexec/orynquix/start-xfce) touch "$state/xfce-runtime" ;;' \
    '        /usr/share/backgrounds/orynquix/orynquix-default.png) touch "$state/wallpaper" ;;' \
    '        */xstartup) touch "$state/xstartup" ;;' \
    '        */vnc.ini) touch "$state/vnc-config" ;;' \
    '        */orynquix-terminal.desktop) touch "$state/terminal-launcher" ;;' \
    '        */orynquix-files.desktop) touch "$state/files-launcher" ;;' \
    '      esac' \
    '    elif [[ "$script" == *password_command* ]]; then' \
    '      cat >/dev/null; touch "$state/vnc-password"' \
    '    fi' \
    '    exit 0 ;;' \
    '  /usr/bin/env)' \
    '    while [[ "${1-}" == *=* ]]; do shift; done' \
    '    nested=${1-}; shift || true' \
    '    if [[ "$nested" == /usr/local/libexec/orynquix/vnc-session ]]; then' \
    '      session_action=${1:-status}; session_display=${2:-1}; session_geometry=${3:-1280x720}' \
    '      case "$session_action" in' \
    '        start) touch "$state/vnc-running"; printf "state=running\npid=4242\ndisplay=:%s\nport=%s\nresolution=%s\nlocalhost=true\n" "$session_display" "$((5900 + session_display))" "$session_geometry" ;;' \
    '        stop) rm -f "$state/vnc-running"; printf "state=stopped\n" ;;' \
    '        status|sessions)' \
    '          if [[ -f "$state/vnc-running" ]]; then printf "state=running\npid=4242\ndisplay=:%s\nport=%s\nresolution=%s\nlocalhost=true\n" "$session_display" "$((5900 + session_display))" "$session_geometry"; else printf "state=stopped\n"; exit 3; fi ;;' \
    '        log) printf "mock VNC log\n" ;;' \
    '      esac' \
    '    elif [[ "$nested" == /usr/local/libexec/orynquix/web-session ]]; then' \
    '      web_action=${1:-status}; web_port=${2:-6080}; vnc_port=${3:-5901}' \
    '      case "$web_action" in' \
    '        start) touch "$state/web-running"; printf "state=running\npid=4343\nweb_port=%s\nvnc_port=%s\nlocalhost=true\n" "$web_port" "$vnc_port" ;;' \
    '        stop) rm -f "$state/web-running"; printf "state=stopped\n" ;;' \
    '        status) if [[ -f "$state/web-running" ]]; then printf "state=running\npid=4343\nweb_port=%s\nvnc_port=%s\nlocalhost=true\n" "$web_port" "$vnc_port"; else printf "state=stopped\n"; exit 3; fi ;;' \
    '        log) printf "mock browser-access log\n" ;;' \
    '      esac' \
    '    elif [[ "$nested" == /usr/bin/apt-get ]]; then' \
    '      printf "Fetched mock packages that must stay in the log\n"' \
    '    fi ;;' \
    '  /usr/bin/xdg-user-dirs-update|/bin/ln|/bin/chmod|/bin/chown)' \
    '    exit 0 ;;' \
    '  *) exit 0 ;;' \
    'esac'

run_install() {
    local output=$1
    shift
    if ! (
        export HOME="$TEST_HOME"
        export PREFIX="$TEST_PREFIX"
        export MOCK_PROOT_STATE="$MOCK_STATE"
        export PATH="$MOCK_BIN:$PATH"
        export NO_COLOR=1
        export ORYNQUIX_TEST_MODE=1
        exec 9<<<'test-passphrase'
        exec 8<<<'vncpass'
        bash "$PROJECT_ROOT/install.sh" --non-interactive --yes --preset standard \
            --viewer both --username testuser --linux-password-fd 9 --vnc-password-fd 8 "$@"
    ) >"$output" 2>&1; then
        printf 'Mock installer failed; captured output follows:\n' >&2
        tail -n 80 "$output" >&2
        return 1
    fi
}

first_output="$TEST_TMP/first-output"
second_output="$TEST_TMP/second-output"
run_install "$first_output"

# Exercise an in-place V3-to-V3.2 refresh: completed stage state exists, while the
# installed CLI and Ubuntu marker identify the previous product release.
installed_cli=$(readlink -f -- "$TEST_PREFIX/bin/orynquix")
printf '#!/usr/bin/env bash\nprintf "Orynquix 0.2.1-alpha\\n"\n' >"$installed_cli"
chmod +x "$installed_cli"
printf 'NAME=Orynquix\nVERSION=0.2.1-alpha\nUBUNTU_VERSION=24.04\n' >"$MOCK_STATE/marker"
run_install "$second_output"

assert() {
    local description=$1
    shift
    if "$@"; then
        printf 'ok - %s\n' "$description"
    else
        printf 'not ok - %s\n' "$description" >&2
        exit 1
    fi
}

assert 'first install reaches the final verified stage' grep -Fq '[16/16 · 100%]' "$first_output"
assert 'current proot-distro OCI mode is detected without a listed Ubuntu alias' grep -Fq 'Ubuntu provisioning mode: oci' "$first_output"
assert 'tested Ubuntu image is selected for current proot-distro' grep -Fxq 'ubuntu:24.04' "$MOCK_STATE/installed-image"
assert 'provider fallback is reported honestly' grep -Fq 'current provider supplied 24.04' "$first_output"
assert 'package download chatter is absent from the terminal' test "$(grep -c 'mock package' "$first_output" || true)" -eq 0
assert 'package output is retained in the private log' grep -Fq 'mock package line' "$TEST_HOME/.orynquix/logs/install.log"
assert 'configuration records actual Ubuntu version' grep -Fxq 'actual_release=24.04' "$TEST_HOME/.orynquix/config.ini"
assert 'configuration records the V3.2 product version' grep -Fxq 'product_version=3.2.0-alpha' "$TEST_HOME/.orynquix/config.ini"
assert 'configuration records browser and VNC desktop access' grep -Fxq 'viewer=both' "$TEST_HOME/.orynquix/config.ini"
assert 'configuration records selected browser' grep -Fxq 'browser=chromium' "$TEST_HOME/.orynquix/config.ini"
assert 'standard Linux user was created' grep -Fxq testuser "$MOCK_STATE/user"
assert 'Linux password passed through stdin reached chpasswd' test -f "$MOCK_STATE/password"
assert 'all sixteen verified stages were persisted' test "$(wc -l <"$TEST_HOME/.orynquix/state/install-state")" -eq 16
assert 'V3-to-V3.2 rerun reuses only the twelve version-independent stable stages' test "$(grep -c 'Already complete and verified' "$second_output")" -eq 12
assert 'rerun displays freshly detected device information' grep -Fq 'ExampleCorp' "$second_output"
assert 'V3-to-V3.2 rerun refreshes the Ubuntu product marker' grep -Fxq 'VERSION=3.2.0-alpha' "$MOCK_STATE/marker"
assert 'installed CLI executes from the Termux prefix' test "$($TEST_PREFIX/bin/orynquix version)" = 'Orynquix 3.2.0-alpha'
assert 'runtime config is private' test "$(stat -c %a "$TEST_HOME/.orynquix/config.ini")" = 600
assert 'installer state is private' test "$(stat -c %a "$TEST_HOME/.orynquix/state/install-state")" = 600

run_cli() {
    HOME="$TEST_HOME" PREFIX="$TEST_PREFIX" MOCK_PROOT_STATE="$MOCK_STATE" \
        PATH="$MOCK_BIN:$PATH" NO_COLOR=1 "$TEST_PREFIX/bin/orynquix" "$@"
}

start_output="$TEST_TMP/start-output"
status_output="$TEST_TMP/status-output"
sessions_output="$TEST_TMP/sessions-output"
restart_output="$TEST_TMP/restart-output"
stop_output="$TEST_TMP/stop-output"
doctor_output="$TEST_TMP/doctor-output"
run_cli start >"$start_output"
run_cli status >"$status_output"
run_cli sessions >"$sessions_output"
run_cli doctor >"$doctor_output"
run_cli theme light >/dev/null
run_cli ui-scale 1.25 >/dev/null
run_cli resolution 1600x900 >/dev/null
run_cli restart >"$restart_output"

assert 'start returns local connection information' grep -Fq 'Connect to: 127.0.0.1:5901' "$start_output"
assert 'start returns browser desktop information' grep -Fq 'Browser desktop: http://127.0.0.1:6080/' "$start_output"
assert 'status reports the managed session as running' grep -Fq 'running' "$status_output"
assert 'sessions prints a managed session table' grep -Fq 'STATE' "$sessions_output"
assert 'doctor verifies the desktop stack' grep -Fq '[✓] TigerVNC configuration' "$doctor_output"
assert 'theme command persists the light theme' grep -Fxq 'theme=orynquix-light' "$TEST_HOME/.orynquix/config.ini"
assert 'UI scale command persists a validated scale' grep -Fxq 'ui_scale=1.25' "$TEST_HOME/.orynquix/config.ini"
assert 'resolution command persists the validated geometry' grep -Fxq 'resolution=1600x900' "$TEST_HOME/.orynquix/config.ini"
assert 'restart leaves the managed session running' test -f "$MOCK_STATE/vnc-running"
assert 'restart leaves browser desktop access running' test -f "$MOCK_STATE/web-running"
run_cli stop >"$stop_output"
assert 'stop terminates only the managed session' test ! -f "$MOCK_STATE/vnc-running"
assert 'stop terminates the managed browser proxy' test ! -f "$MOCK_STATE/web-running"

stopped_status_output="$TEST_TMP/stopped-status-output"
if run_cli status >"$stopped_status_output"; then stopped_status_rc=0; else stopped_status_rc=$?; fi
assert 'stopped status returns a non-running exit code' test "$stopped_status_rc" -eq 3
assert 'stopped status remains human readable' grep -Fq 'stopped' "$stopped_status_output"

passwd_output="$TEST_TMP/passwd-output"
(
    exec 7<<<'newpass7'
    run_cli passwd --password-fd 7
) >"$passwd_output"
assert 'VNC password can be changed through a secure descriptor' grep -Fq 'VNC password configured securely' "$passwd_output"

nested_output="$TEST_TMP/nested-output"
if ORYNQUIX_INSIDE_PROOT=1 run_cli start >"$nested_output" 2>&1; then nested_rc=0; else nested_rc=$?; fi
assert 'host command refuses nested PRoot execution' test "$nested_rc" -eq 2
assert 'nested PRoot error tells the user to exit' grep -Fq 'exit' "$nested_output"

printf 'Mock clean-install, rerun, and VNC lifecycle integration test passed.\n'
