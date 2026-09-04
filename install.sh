#!/usr/bin/env bash
set -Eeuo pipefail

ORYNQUIX_PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export ORYNQUIX_PROJECT_ROOT

# shellcheck source=lib/config.sh
source "$ORYNQUIX_PROJECT_ROOT/lib/config.sh"
# shellcheck source=lib/output.sh
source "$ORYNQUIX_PROJECT_ROOT/lib/output.sh"
# shellcheck source=lib/filesystem.sh
source "$ORYNQUIX_PROJECT_ROOT/lib/filesystem.sh"
# shellcheck source=lib/process.sh
source "$ORYNQUIX_PROJECT_ROOT/lib/process.sh"
# shellcheck source=lib/ubuntu.sh
source "$ORYNQUIX_PROJECT_ROOT/lib/ubuntu.sh"
# shellcheck source=installer/logging.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/logging.sh"
# shellcheck source=installer/state.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/state.sh"
# shellcheck source=installer/core.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/core.sh"
# shellcheck source=installer/environment.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/environment.sh"
# shellcheck source=installer/device.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/device.sh"
# shellcheck source=installer/network.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/network.sh"
# shellcheck source=installer/choices.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/choices.sh"
# shellcheck source=installer/dependencies.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/dependencies.sh"
# shellcheck source=installer/ubuntu.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/ubuntu.sh"
# shellcheck source=installer/users.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/users.sh"
# shellcheck source=installer/desktop.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/desktop.sh"
# shellcheck source=installer/vnc.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/vnc.sh"
# shellcheck source=installer/access.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/access.sh"
# shellcheck source=installer/apps.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/apps.sh"
# shellcheck source=installer/theme.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/theme.sh"
# shellcheck source=installer/validation.sh
source "$ORYNQUIX_PROJECT_ROOT/installer/validation.sh"

main() {
    parse_install_args "$@"
    validate_install_args
    guard_host_environment
    trap on_installer_error ERR
    trap on_installer_interrupt INT TERM
    trap cleanup_installer EXIT

    if [[ "$ORYNQUIX_DRY_RUN" == 1 ]]; then
        init_dry_run_logging
    else
        init_runtime_layout
        init_logging
        load_state
        acquire_install_lock
    fi

    show_banner
    run_stage environment 'Environment' validate_termux_environment verify_termux_environment
    run_live_stage device 'Current device detection' detect_and_show_device validate_supported_device
    run_stage choices 'Installation choices' configure_installation_choices verify_choices
    run_stage network 'Network and DNS' check_network verify_network
    run_stage termux_dependencies 'Termux dependencies' install_termux_dependencies verify_termux_dependencies
    run_stage ubuntu_provider 'Ubuntu provider discovery' discover_ubuntu_provider verify_ubuntu_provider
    run_stage ubuntu_install 'Ubuntu installation' install_ubuntu_rootfs verify_ubuntu_rootfs
    run_stage ubuntu_init 'Ubuntu initialization' initialize_ubuntu verify_ubuntu_initialization
    run_stage ubuntu_user 'Standard Linux user' create_linux_user verify_linux_user
    run_stage desktop 'XFCE desktop' install_desktop verify_desktop
    run_stage vnc 'TigerVNC and desktop startup' configure_vnc verify_vnc_configuration
    run_stage access 'VNC app and browser access' configure_desktop_access verify_desktop_access
    run_stage apps 'Selected applications and development tools' install_selected_applications verify_selected_applications
    run_stage theme 'Orynquix desktop appearance' configure_orynquix_appearance verify_orynquix_appearance
    run_stage cli 'Orynquix CLI' install_orynquix_cli verify_orynquix_cli
    run_stage validation 'Final installation validation' validate_installation verify_installation

    finish_installation
}

detect_and_show_device() {
    detect_device
    show_device_information
}

main "$@"
