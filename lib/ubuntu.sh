#!/usr/bin/env bash

proot_distro_available() {
    command -v proot-distro >/dev/null 2>&1
}

inside_orynquix_proot() {
    [[ "${ORYNQUIX_INSIDE_PROOT:-0}" == 1 || -f /etc/orynquix-release ]]
}

ubuntu_provider_available() {
    proot-distro list 2>/dev/null | awk '
        BEGIN { found=0 }
        {
            line=tolower($0)
            if (line ~ /ubuntu/ && (line ~ /<[[:space:]]*ubuntu[[:space:]]*>/ || line ~ /alias[^a-z0-9]+ubuntu([^a-z0-9]|$)/)) found=1
        }
        END { exit(found ? 0 : 1) }
    '
}

ubuntu_rootfs_works() {
    proot_distro_available || return 1
    proot-distro login "$ORYNQUIX_DISTRIBUTION" -- /usr/bin/test -r /etc/os-release >/dev/null 2>&1
}

run_in_ubuntu() {
    proot-distro login "$ORYNQUIX_DISTRIBUTION" -- "$@"
}

run_as_ubuntu_user() {
    local username=$1
    shift
    proot-distro login --user "$username" "$ORYNQUIX_DISTRIBUTION" -- "$@"
}

atomic_install_in_ubuntu() {
    local target=$1 mode=$2 owner=$3
    [[ "$target" == /* && "$target" != / ]] || {
        log_error "Invalid Ubuntu target path: $target"
        return 1
    }
    [[ "$mode" =~ ^0?[0-7]{3,4}$ ]] || {
        log_error "Invalid Ubuntu file mode: $mode"
        return 1
    }
    [[ "$owner" == root:root || "$owner" =~ ^[a-z_][a-z0-9_-]{0,31}:[a-z_][a-z0-9_-]{0,31}$ ]] || {
        log_error "Invalid Ubuntu file owner: $owner"
        return 1
    }
    run_in_ubuntu /bin/sh -c '
        set -eu
        target=$1
        mode=$2
        owner=$3
        directory=${target%/*}
        temporary="${directory}/.orynquix.$$.tmp"
        previous="${target}.previous"
        mkdir -p "$directory"
        umask 077
        trap '\''rm -f "$temporary"'\'' EXIT HUP INT TERM
        cat >"$temporary"
        test -s "$temporary"
        chmod "$mode" "$temporary"
        chown "$owner" "$temporary"
        if test -e "$target"; then cp -p "$target" "$previous"; fi
        mv -f "$temporary" "$target"
        trap - EXIT HUP INT TERM
    ' orynquix-atomic "$target" "$mode" "$owner"
}

read_ubuntu_os_release() {
    local content key value
    content=$(run_in_ubuntu /bin/cat /etc/os-release) || return 1
    ORYNQUIX_ACTUAL_UBUNTU_VERSION=''
    ORYNQUIX_ACTUAL_UBUNTU_NAME=''
    ORYNQUIX_ACTUAL_UBUNTU_CODENAME=''
    while IFS='=' read -r key value; do
        value=${value#\"}; value=${value%\"}
        value=${value#\'}; value=${value%\'}
        case "$key" in
            ID) [[ "$value" == ubuntu ]] || { log_error "Provider installed '$value', not Ubuntu."; return 1; } ;;
            VERSION_ID) ORYNQUIX_ACTUAL_UBUNTU_VERSION=$value ;;
            PRETTY_NAME) ORYNQUIX_ACTUAL_UBUNTU_NAME=$value ;;
            VERSION_CODENAME|UBUNTU_CODENAME) [[ -n "$ORYNQUIX_ACTUAL_UBUNTU_CODENAME" ]] || ORYNQUIX_ACTUAL_UBUNTU_CODENAME=$value ;;
        esac
    done <<<"$content"
    [[ -n "$ORYNQUIX_ACTUAL_UBUNTU_VERSION" ]]
}

ubuntu_package_exists() {
    run_in_ubuntu /usr/bin/apt-cache show "$1" >/dev/null 2>&1
}

ubuntu_package_installed() {
    run_in_ubuntu /usr/bin/dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx 'installed'
}

ubuntu_user_exists() {
    run_in_ubuntu /usr/bin/id "$ORYNQUIX_USERNAME" >/dev/null 2>&1
}
