#!/usr/bin/env bash

discover_ubuntu_provider() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 && ! -x "${PREFIX:-}/bin/proot-distro" ]]; then
        log_info '[dry-run] Would inspect proot-distro for an Ubuntu provider'
        return 0
    fi
    proot_distro_available || { log_error 'proot-distro is not installed.'; return 1; }
    ubuntu_provider_available || {
        log_error 'The installed proot-distro does not advertise an Ubuntu provider.'
        log_error 'Orynquix will not silently install Debian.'
        return 1
    }
    ORYNQUIX_PROOT_DISTRO_VERSION=$(proot-distro --version 2>/dev/null | head -n1 || true)
    log_success "Ubuntu provider found (${ORYNQUIX_PROOT_DISTRO_VERSION:-version unavailable})"
}

verify_ubuntu_provider() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    proot_distro_available && ubuntu_provider_available
}

install_ubuntu_rootfs() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 ]]; then
        log_info '[dry-run] Would install or reuse the verified Ubuntu provider'
        return 0
    fi
    if ubuntu_rootfs_works; then
        log_success 'Existing Ubuntu root filesystem is healthy; reusing it'
    else
        run_visible_or_logged 'Installing Ubuntu root filesystem' "$ORYNQUIX_INSTALL_LOG" \
            proot-distro install "$ORYNQUIX_DISTRIBUTION"
    fi
    read_ubuntu_os_release
    log_success "Verified ${ORYNQUIX_ACTUAL_UBUNTU_NAME}"
    if [[ "$ORYNQUIX_ACTUAL_UBUNTU_VERSION" != "$ORYNQUIX_PREFERRED_UBUNTU" ]]; then
        log_warn "Ubuntu $ORYNQUIX_PREFERRED_UBUNTU was preferred but the current provider supplied $ORYNQUIX_ACTUAL_UBUNTU_VERSION."
        log_warn 'The installed release is reported honestly; no distribution substitution occurred.'
    fi
    write_actual_ubuntu_release
}

write_actual_ubuntu_release() {
    local temporary
    temporary=$(mktemp "${ORYNQUIX_CONFIG_FILE}.ubuntu.XXXXXX")
    awk -v version="$ORYNQUIX_ACTUAL_UBUNTU_VERSION" '
        /^actual_release=/ { print "actual_release=" version; next }
        { print }
    ' "$ORYNQUIX_CONFIG_FILE" >"$temporary"
    cat "$temporary" | atomic_write "$ORYNQUIX_CONFIG_FILE" 600
    rm -f -- "$temporary"
    printf '%s\n' "$ORYNQUIX_ACTUAL_UBUNTU_VERSION" | atomic_write "$ORYNQUIX_STATE_DIR/ubuntu-release" 600
}

verify_ubuntu_rootfs() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    ubuntu_rootfs_works && read_ubuntu_os_release
}

repair_ubuntu_packages() {
    run_in_ubuntu /usr/bin/dpkg --configure -a
    run_in_ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -f install -y
}

initialize_ubuntu() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && { log_info '[dry-run] Would initialize locale, timezone, certificates, sudo and XDG directories'; return 0; }
    local timezone=${TZ:-}
    [[ -n "$timezone" ]] || timezone=$(get_android_property persist.sys.timezone)
    [[ -n "$timezone" ]] || timezone=UTC

    run_visible_or_logged 'Refreshing Ubuntu package metadata' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /usr/bin/apt-get update -q
    run_visible_or_logged 'Installing Ubuntu foundation packages' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y -q \
            sudo locales tzdata ca-certificates dbus-x11 xdg-user-dirs bash-completion

    if run_in_ubuntu /usr/bin/test -e "/usr/share/zoneinfo/$timezone"; then
        run_in_ubuntu /bin/ln -snf "/usr/share/zoneinfo/$timezone" /etc/localtime
        printf '%s\n' "$timezone" | run_in_ubuntu /usr/bin/tee /etc/timezone >/dev/null
    else
        log_warn "Android timezone '$timezone' is unavailable in Ubuntu; using UTC."
        run_in_ubuntu /bin/ln -snf /usr/share/zoneinfo/UTC /etc/localtime
        printf '%s\n' UTC | run_in_ubuntu /usr/bin/tee /etc/timezone >/dev/null
    fi
    run_in_ubuntu /usr/sbin/locale-gen en_US.UTF-8 >/dev/null
    run_in_ubuntu /usr/sbin/update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
}

verify_ubuntu_initialization() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    run_in_ubuntu /usr/bin/test -x /usr/bin/sudo &&
        run_in_ubuntu /usr/bin/test -x /usr/bin/dbus-launch &&
        run_in_ubuntu /usr/bin/test -d /usr/share/zoneinfo
}
