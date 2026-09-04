#!/usr/bin/env bash

validate_installation() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && { log_success 'Dry-run plan completed without device changes'; return 0; }
    local failures=0
    verify_termux_environment || { log_error 'Termux validation failed'; failures=$((failures + 1)); }
    verify_termux_dependencies || { log_error 'Host dependency validation failed'; failures=$((failures + 1)); }
    verify_ubuntu_rootfs || { log_error 'Ubuntu rootfs validation failed'; failures=$((failures + 1)); }
    verify_ubuntu_initialization || { log_error 'Ubuntu initialization validation failed'; failures=$((failures + 1)); }
    verify_linux_user || { log_error 'Linux user validation failed'; failures=$((failures + 1)); }
    verify_desktop || { log_error 'XFCE desktop validation failed'; failures=$((failures + 1)); }
    verify_vnc_configuration || { log_error 'TigerVNC configuration validation failed'; failures=$((failures + 1)); }
    verify_desktop_access || { log_error 'Desktop access validation failed'; failures=$((failures + 1)); }
    verify_selected_applications || { log_error 'Selected application validation failed'; failures=$((failures + 1)); }
    verify_orynquix_appearance || { log_error 'Orynquix appearance validation failed'; failures=$((failures + 1)); }
    verify_choices || { log_error 'Configuration validation failed'; failures=$((failures + 1)); }
    verify_orynquix_cli || { log_error 'CLI validation failed'; failures=$((failures + 1)); }
    (( failures == 0 )) || return 1
    log_success 'Foundation and desktop checks passed'
}

verify_installation() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    verify_ubuntu_rootfs && verify_linux_user && verify_desktop && verify_vnc_configuration &&
        verify_desktop_access && verify_selected_applications && verify_orynquix_appearance &&
        verify_orynquix_cli
}
