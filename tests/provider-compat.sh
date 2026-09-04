#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_TMP=$(mktemp -d /tmp/orynquix-provider-tests.XXXXXX)
MOCK_BIN="$TEST_TMP/bin"
mkdir -p "$MOCK_BIN"

cleanup() {
    case "$TEST_TMP" in
        /tmp/orynquix-provider-tests.*) find "$TEST_TMP" -depth -delete ;;
    esac
}
trap cleanup EXIT

export PATH="$MOCK_BIN:$PATH"
export PREFIX="$TEST_TMP/prefix"
export ORYNQUIX_PROJECT_ROOT="$PROJECT_ROOT"

# shellcheck source=../lib/config.sh
source "$PROJECT_ROOT/lib/config.sh"
# shellcheck source=../lib/ubuntu.sh
source "$PROJECT_ROOT/lib/ubuntu.sh"

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

write_current_mock() {
    cat >"$MOCK_BIN/proot-distro" <<'EOF'
#!/usr/bin/env bash
if [[ "${1-}" == install && "${2-}" == --help ]]; then
    printf 'usage: proot-distro install [--name NAME] IMAGE from OCI registry\n'
elif [[ "${1-}" == list ]]; then
    printf 'No containers installed.\n'
fi
EOF
    chmod 755 "$MOCK_BIN/proot-distro"
}

write_legacy_mock() {
    cat >"$MOCK_BIN/proot-distro" <<'EOF'
#!/usr/bin/env bash
if [[ "${1-}" == install && "${2-}" == --help ]]; then
    printf 'usage: proot-distro install ALIAS\n'
elif [[ "${1-}" == list ]]; then
    printf 'Ubuntu < ubuntu >\n'
fi
EOF
    chmod 755 "$MOCK_BIN/proot-distro"
}

write_current_mock
ORYNQUIX_UBUNTU_RELEASE=24.04
select_ubuntu_install_source
check 'current OCI provider mode is detected without an Ubuntu alias' test "$ORYNQUIX_PROOT_MODE" = oci
check 'current provider selects a release-specific Ubuntu image' test "$ORYNQUIX_UBUNTU_IMAGE" = ubuntu:24.04

ORYNQUIX_UBUNTU_RELEASE=26.04
select_ubuntu_install_source
check 'current provider accepts explicit Ubuntu 26.04 selection' test "$ORYNQUIX_UBUNTU_IMAGE" = ubuntu:26.04

write_legacy_mock
ORYNQUIX_UBUNTU_RELEASE=24.04
select_ubuntu_install_source
check 'legacy alias provider remains supported' test "$ORYNQUIX_PROOT_MODE" = legacy
check 'legacy provider selects only the verified Ubuntu alias' test "$ORYNQUIX_UBUNTU_IMAGE" = ubuntu

printf '1..%d\n' "$tests"
(( failures == 0 )) || exit 1
printf 'All %d provider compatibility tests passed.\n' "$tests"
