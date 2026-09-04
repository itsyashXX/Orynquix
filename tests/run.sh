#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_TMP=$(mktemp -d /tmp/orynquix-tests.XXXXXX)
export HOME="$TEST_TMP/home"
mkdir -p "$HOME"

cleanup() {
    case "$TEST_TMP" in
        /tmp/orynquix-tests.*) find "$TEST_TMP" -depth -delete ;;
    esac
}
trap cleanup EXIT

export ORYNQUIX_PROJECT_ROOT=$PROJECT_ROOT
export ORYNQUIX_TEST_MODE=1
export NO_COLOR=1

# shellcheck source=../lib/config.sh
source "$PROJECT_ROOT/lib/config.sh"
# shellcheck source=../lib/output.sh
source "$PROJECT_ROOT/lib/output.sh"
# shellcheck source=../lib/filesystem.sh
source "$PROJECT_ROOT/lib/filesystem.sh"
# shellcheck source=../installer/state.sh
source "$PROJECT_ROOT/installer/state.sh"
# shellcheck source=../installer/choices.sh
source "$PROJECT_ROOT/installer/choices.sh"
# shellcheck source=../installer/device.sh
source "$PROJECT_ROOT/installer/device.sh"
# shellcheck source=../installer/users.sh
source "$PROJECT_ROOT/installer/users.sh"
# shellcheck source=../installer/vnc.sh
source "$PROJECT_ROOT/installer/vnc.sh"

tests_run=0
tests_failed=0

pass() { printf 'ok %d - %s\n' "$tests_run" "$1"; }
fail() { printf 'not ok %d - %s\n' "$tests_run" "$1"; tests_failed=$((tests_failed + 1)); }

check() {
    local name=$1
    shift
    tests_run=$((tests_run + 1))
    if "$@"; then pass "$name"; else fail "$name"; fi
}

assert_eq() { [[ "${1-}" == "${2-}" ]]; }
assert_file_absent() { [[ ! -e "$1" ]]; }
assert_contains() { grep -Fq -- "$2" "$1"; }
assert_false() { ! "$@"; }
assert_false_silent() { ! "$@" >/dev/null 2>&1; }

check 'accepts a normal username' validate_username orynquix
check 'rejects the root username' assert_false validate_username root
check 'rejects uppercase usernames' assert_false validate_username Yash
check 'accepts the default resolution' validate_resolution 1280x720
check 'rejects an undersized resolution' assert_false validate_resolution 320x200
check 'rejects resolution shell text' assert_false validate_resolution '1280x720;id'
check 'accepts a supported UI scale' validate_ui_scale 1.25
check 'rejects an arbitrary UI scale' assert_false validate_ui_scale 1.3
check 'accepts display one' validate_display_number 1
check 'rejects display zero' assert_false validate_display_number 0
check 'accepts VNC depth 24' validate_depth 24
check 'rejects unsupported VNC depth' assert_false validate_depth 12
check 'accepts an eight-character VNC password' validate_vnc_password_value passw0rd
check 'rejects an overlong legacy VNC password' assert_false_silent validate_vnc_password_value ninechars
check 'rejects a Linux password containing a line break' assert_false_silent validate_linux_password $'secure\nroot:owned'
check 'accepts a safe custom development list' validate_custom_dev_list python,node,git
check 'rejects an unknown development group' assert_false validate_custom_dev_list python,unknown

config_fixture="$TEST_TMP/config.ini"
printf '[system]\nprofile=standard\n[user]\nname=orynquix\n' | atomic_write "$config_fixture" 600
check 'reads an INI value by section' assert_eq "$(config_get system profile "$config_fixture")" standard
check 'writes private configuration permissions' assert_eq "$(stat -c %a "$config_fixture")" 600

ORYNQUIX_STATE_FILE="$TEST_TMP/install-state"
ORYNQUIX_STATE_DIR="$TEST_TMP"
ORYNQUIX_STAGE_STATE=()
mark_stage_complete ubuntu_install >/dev/null
load_state
check 'persists a completed installer stage' stage_completed ubuntu_install
check 'does not invent another completed stage' assert_false stage_completed desktop

recommend_device_profile 3145728
check 'recommends lite below 4 GiB' assert_eq "$ORYNQUIX_RECOMMENDED_PROFILE" lite
check 'recommends 1024x600 below 4 GiB' assert_eq "$ORYNQUIX_RECOMMENDED_RESOLUTION" 1024x600
recommend_device_profile 5242880
check 'recommends standard from 4–6 GiB' assert_eq "$ORYNQUIX_RECOMMENDED_PROFILE" standard
recommend_device_profile 8388608
check 'recommends developer from 6 GiB' assert_eq "$ORYNQUIX_RECOMMENDED_PROFILE" developer

dry_home="$TEST_TMP/dry-home"
mkdir -p "$dry_home"
dry_output="$TEST_TMP/dry-output"
if HOME="$dry_home" NO_COLOR=1 bash "$PROJECT_ROOT/install.sh" --dry-run --non-interactive --yes --preset standard >"$dry_output" 2>&1; then
    tests_run=$((tests_run + 1)); pass 'non-interactive dry-run completes'
else
    tests_run=$((tests_run + 1)); fail 'non-interactive dry-run completes'
fi
check 'dry-run reaches exactly 100 percent' assert_contains "$dry_output" '[13/13 · 100%]'
check 'dry-run is labelled honestly' assert_contains "$dry_output" 'DRY RUN COMPLETE'
check 'dry-run leaves HOME unchanged' assert_file_absent "$dry_home/.orynquix"

custom_home="$TEST_TMP/custom-home"
mkdir -p "$custom_home"
custom_output="$TEST_TMP/custom-output"
if HOME="$custom_home" NO_COLOR=1 bash "$PROJECT_ROOT/install.sh" --dry-run --non-interactive --yes \
    --preset custom --browser both --editor none --dev-tools custom:git,python \
    --username developer --resolution 1600x900 >"$custom_output" 2>&1; then
    tests_run=$((tests_run + 1)); pass 'custom non-interactive selection completes'
else
    tests_run=$((tests_run + 1)); fail 'custom non-interactive selection completes'
fi
check 'custom plan records both browsers' assert_contains "$custom_output" 'Browser            both'
check 'custom plan records an editor skip' assert_contains "$custom_output" 'Editor             none'
check 'custom plan records selected coding groups' assert_contains "$custom_output" 'Development tools  custom:git,python'
check 'custom dry-run leaves HOME unchanged' assert_file_absent "$custom_home/.orynquix"

menu_output="$TEST_TMP/menu-output"
ORYNQUIX_PROFILE=''
if choose_profile_interactive >"$menu_output" <<<"2" && [[ "$ORYNQUIX_PROFILE" == complete ]]; then
    tests_run=$((tests_run + 1)); pass 'interactive preset selection returns Complete to its caller'
else
    tests_run=$((tests_run + 1)); fail 'interactive preset selection returns Complete to its caller'
fi
ORYNQUIX_BROWSER=''
if choose_browser_interactive >>"$menu_output" <<<"3" && [[ "$ORYNQUIX_BROWSER" == both ]]; then
    tests_run=$((tests_run + 1)); pass 'interactive browser selection returns Both to its caller'
else
    tests_run=$((tests_run + 1)); fail 'interactive browser selection returns Both to its caller'
fi
ORYNQUIX_EDITOR=''
if choose_editor_interactive >>"$menu_output" <<<"4" && [[ "$ORYNQUIX_EDITOR" == both ]]; then
    tests_run=$((tests_run + 1)); pass 'interactive editor selection returns Both to its caller'
else
    tests_run=$((tests_run + 1)); fail 'interactive editor selection returns Both to its caller'
fi
ORYNQUIX_DEV_TOOLS=''
if choose_dev_tools_interactive >>"$menu_output" <<'EOF' && [[ "$ORYNQUIX_DEV_TOOLS" == full ]]; then
yes
2
EOF
    tests_run=$((tests_run + 1)); pass 'interactive coding-tools selection returns Full to its caller'
else
    tests_run=$((tests_run + 1)); fail 'interactive coding-tools selection returns Full to its caller'
fi

invalid_output="$TEST_TMP/invalid-output"
tests_run=$((tests_run + 1))
if HOME="$dry_home" bash "$PROJECT_ROOT/install.sh" --dry-run --preset impossible >"$invalid_output" 2>&1; then
    fail 'invalid preset exits non-zero'
else
    pass 'invalid preset exits non-zero'
fi

check 'CLI reports its version' bash -c '[[ "$1" == "Orynquix 0.2.1-alpha" ]]' _ "$($PROJECT_ROOT/bin/orynquix version)"
check 'CLI version command rejects extra arguments' bash -c '! "$1" version unexpected >/dev/null 2>&1' _ "$PROJECT_ROOT/bin/orynquix"

printf '1..%d\n' "$tests_run"
if (( tests_failed > 0 )); then
    printf '%d test(s) failed.\n' "$tests_failed" >&2
    exit 1
fi
printf 'All %d tests passed.\n' "$tests_run"
