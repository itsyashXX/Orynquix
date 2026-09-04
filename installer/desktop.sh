#!/usr/bin/env bash

desktop_packages_for_profile() {
    ORYNQUIX_DESKTOP_REQUIRED_PACKAGES=(
        xfce4 xfce4-terminal thunar dbus-x11 x11-xserver-utils x11-utils
    )
    ORYNQUIX_DESKTOP_OPTIONAL_PACKAGES=(
        mousepad ristretto xarchiver xfce4-appfinder xfce4-notifyd
    )
    if [[ "$ORYNQUIX_PROFILE" != lite ]]; then
        ORYNQUIX_DESKTOP_OPTIONAL_PACKAGES+=(xfce4-goodies xfce4-clipman-plugin)
    fi
}

select_available_desktop_packages() {
    local package
    ORYNQUIX_DESKTOP_PACKAGES=("${ORYNQUIX_DESKTOP_REQUIRED_PACKAGES[@]}")
    for package in "${ORYNQUIX_DESKTOP_OPTIONAL_PACKAGES[@]}"; do
        if ubuntu_package_exists "$package"; then
            ORYNQUIX_DESKTOP_PACKAGES+=("$package")
        else
            log_warn "Optional desktop package is unavailable and will be skipped: $package"
        fi
    done
}

verify_packages_available() {
    local package
    for package in "$@"; do
        ubuntu_package_exists "$package" || {
            log_error "Required Ubuntu package is unavailable: $package"
            return 1
        }
    done
}

install_desktop() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 ]]; then
        log_info '[dry-run] Would install the selected XFCE desktop components'
        return 0
    fi
    desktop_packages_for_profile
    verify_packages_available "${ORYNQUIX_DESKTOP_REQUIRED_PACKAGES[@]}"
    select_available_desktop_packages
    run_visible_or_logged 'Installing XFCE desktop components' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y -q \
            "${ORYNQUIX_DESKTOP_PACKAGES[@]}"
}

verify_desktop() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    run_in_ubuntu /bin/sh -c '
        command -v xfce4-session >/dev/null 2>&1 &&
        command -v xfce4-terminal >/dev/null 2>&1 &&
        command -v thunar >/dev/null 2>&1 &&
        command -v dbus-launch >/dev/null 2>&1
    '
}
