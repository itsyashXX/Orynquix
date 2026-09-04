#!/usr/bin/env bash

ORYNQUIX_TOTAL_STAGES=13
ORYNQUIX_CURRENT_STAGE=0
ORYNQUIX_LOCK_HELD=0

usage() {
    cat <<'EOF'
Usage: bash install.sh [options]

Options:
  --preset NAME          lite, standard, developer, complete, or custom
  --browser NAME         chromium, firefox, both, or none
  --editor NAME          auto, vscode, code-server, both, or none
  --dev-tools NAME       none, recommended, full, or custom:python,node,...
  --username NAME        Linux desktop username
  --resolution WIDTHxHEIGHT
  --reconfigure          Ask installation-choice questions again
  --non-interactive      Use validated defaults/arguments; never prompt
  --linux-password-fd N  Read the Linux password from open file descriptor N
  --vnc-password-fd N    Read the VNC password from open file descriptor N
  --yes                  Accept the displayed plan
  --dry-run              Detect and plan without changing the device
  --verbose              Show underlying package-manager output
  --quiet                Print errors only
  --debug                Include command/line context in errors
  --help                  Show this help

Default output intentionally hides package download chatter. Full output is
always written to ~/.orynquix/logs/install.log.
EOF
}

require_option_value() {
    local option=$1 value=${2-}
    [[ -n "$value" && "$value" != --* ]] || {
        log_error "$option requires a value."
        exit 64
    }
}

parse_install_args() {
    while (( $# )); do
        case "$1" in
            --preset)
                require_option_value "$1" "${2-}"; ORYNQUIX_PROFILE=$2; shift 2 ;;
            --browser)
                require_option_value "$1" "${2-}"; ORYNQUIX_BROWSER=$2; shift 2 ;;
            --editor)
                require_option_value "$1" "${2-}"; ORYNQUIX_EDITOR=$2; shift 2 ;;
            --dev-tools)
                require_option_value "$1" "${2-}"; ORYNQUIX_DEV_TOOLS=$2; shift 2 ;;
            --username)
                require_option_value "$1" "${2-}"; ORYNQUIX_USERNAME=$2; shift 2 ;;
            --resolution)
                require_option_value "$1" "${2-}"; ORYNQUIX_RESOLUTION=$2; shift 2 ;;
            --linux-password-fd)
                require_option_value "$1" "${2-}"; ORYNQUIX_LINUX_PASSWORD_FD=$2; shift 2 ;;
            --vnc-password-fd)
                require_option_value "$1" "${2-}"; ORYNQUIX_VNC_PASSWORD_FD=$2; shift 2 ;;
            --reconfigure) ORYNQUIX_RECONFIGURE=1; shift ;;
            --non-interactive) ORYNQUIX_NON_INTERACTIVE=1; shift ;;
            --yes) ORYNQUIX_ASSUME_YES=1; shift ;;
            --dry-run) ORYNQUIX_DRY_RUN=1; shift ;;
            --verbose) ORYNQUIX_VERBOSE=1; shift ;;
            --quiet) ORYNQUIX_QUIET=1; shift ;;
            --debug) ORYNQUIX_DEBUG=1; shift ;;
            --help|-h) usage; exit 0 ;;
            *) log_error "Unknown installer option: $1"; usage >&2; exit 64 ;;
        esac
    done
}

validate_install_args() {
    [[ -z "$ORYNQUIX_PROFILE" ]] || validate_profile "$ORYNQUIX_PROFILE" || {
        log_error "Invalid preset: $ORYNQUIX_PROFILE"; return 64;
    }
    [[ -z "$ORYNQUIX_BROWSER" ]] || validate_browser_choice "$ORYNQUIX_BROWSER" || {
        log_error "Invalid browser choice: $ORYNQUIX_BROWSER"; return 64;
    }
    [[ -z "$ORYNQUIX_EDITOR" ]] || validate_editor_choice "$ORYNQUIX_EDITOR" || {
        log_error "Invalid editor choice: $ORYNQUIX_EDITOR"; return 64;
    }
    [[ -z "$ORYNQUIX_DEV_TOOLS" ]] || validate_dev_tools_choice "$ORYNQUIX_DEV_TOOLS" || {
        log_error "Invalid development-tool choice: $ORYNQUIX_DEV_TOOLS"; return 64;
    }
    validate_username "$ORYNQUIX_USERNAME" || {
        log_error "Invalid or reserved Linux username: $ORYNQUIX_USERNAME"; return 64;
    }
    [[ -z "$ORYNQUIX_RESOLUTION" ]] || validate_resolution "$ORYNQUIX_RESOLUTION" || {
        log_error "Resolution must be WIDTHxHEIGHT within 640x480–7680x4320."; return 64;
    }
    [[ -z "$ORYNQUIX_LINUX_PASSWORD_FD" || "$ORYNQUIX_LINUX_PASSWORD_FD" =~ ^[0-9]+$ ]] || {
        log_error "--linux-password-fd requires a numeric file descriptor."; return 64;
    }
    [[ -z "$ORYNQUIX_VNC_PASSWORD_FD" || "$ORYNQUIX_VNC_PASSWORD_FD" =~ ^[0-9]+$ ]] || {
        log_error "--vnc-password-fd requires a numeric file descriptor."; return 64;
    }
}

init_runtime_layout() {
    secure_mkdir "$ORYNQUIX_HOME" 700
    secure_mkdir "$ORYNQUIX_STATE_DIR" 700
    secure_mkdir "$ORYNQUIX_BACKUP_DIR" 700
    secure_mkdir "$ORYNQUIX_DATA_DIR" 700
}

init_dry_run_logging() {
    ORYNQUIX_INSTALL_LOG=$(mktemp /tmp/orynquix-dry-run.XXXXXX)
    chmod 600 "$ORYNQUIX_INSTALL_LOG"
}

cleanup_installer() {
    release_install_lock
    if [[ "${ORYNQUIX_DRY_RUN:-0}" == 1 && -n "${ORYNQUIX_INSTALL_LOG:-}" ]]; then
        case "$ORYNQUIX_INSTALL_LOG" in
            /tmp/orynquix-dry-run.*) rm -f -- "$ORYNQUIX_INSTALL_LOG" ;;
        esac
    fi
}

guard_host_environment() {
    inside_orynquix_proot || return 0
    cat >&2 <<'EOF'
You're already inside Orynquix Ubuntu.

This installer manages Orynquix from Termux. Run:

  exit

to return to Termux and retry.
EOF
    return 2
}

on_installer_error() {
    local rc=$? line=${BASH_LINENO[0]:-${LINENO}} command=${BASH_COMMAND:-unknown}
    trap - ERR
    [[ -n "${ORYNQUIX_INSTALL_LOG:-}" ]] && record_failure_context "$rc" "$line" "$command"
    if [[ "${ORYNQUIX_DEBUG:-0}" == 1 ]]; then
        log_error "Installer stopped at line $line (exit $rc): $command"
    else
        log_error "Installer stopped safely. Completed stages were preserved."
        [[ -n "${ORYNQUIX_INSTALL_LOG:-}" ]] && printf '  Log: %s\n' "$ORYNQUIX_INSTALL_LOG" >&2
        printf '  Re-run bash install.sh after correcting the reported problem.\n' >&2
    fi
    release_install_lock
    exit "$rc"
}

on_installer_interrupt() {
    log_warn "Installation interrupted. Completed and verified stages were preserved."
    release_install_lock
    exit 130
}

run_stage() {
    local key=$1 label=$2 action=$3 verifier=${4-}
    ORYNQUIX_CURRENT_STAGE=$((ORYNQUIX_CURRENT_STAGE + 1))
    stage_heading "$ORYNQUIX_CURRENT_STAGE" "$ORYNQUIX_TOTAL_STAGES" "$label"

    if stage_completed "$key" && [[ -n "$verifier" ]] && "$verifier"; then
        log_success "Already complete and verified"
        return 0
    fi

    "$action"
    if [[ -n "$verifier" ]]; then
        "$verifier" || {
            log_error "$label finished but validation failed; the stage was not saved."
            return 1
        }
    fi
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] || mark_stage_complete "$key"
}

run_live_stage() {
    local key=$1 label=$2 action=$3 verifier=${4-}
    ORYNQUIX_CURRENT_STAGE=$((ORYNQUIX_CURRENT_STAGE + 1))
    stage_heading "$ORYNQUIX_CURRENT_STAGE" "$ORYNQUIX_TOTAL_STAGES" "$label"
    "$action"
    if [[ -n "$verifier" ]]; then
        "$verifier" || {
            log_error "$label finished but validation failed; the stage was not saved."
            return 1
        }
    fi
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] || mark_stage_complete "$key"
}

finish_installation() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 ]]; then
        printf '\n%sDRY RUN COMPLETE%s\n' "$C_BOLD" "$C_RESET"
        printf 'No Termux packages, Ubuntu filesystems, users, or configuration were changed.\n'
        printf 'Run bash install.sh when you are ready to install.\n'
        return 0
    fi
    printf '\n%s\n' "${C_BOLD}╭────────────────────────────────────────────────────────────╮"
    printf '%s\n' "│                    ORYNQUIX IS READY                       │"
    printf '%s\n' "╰────────────────────────────────────────────────────────────╯${C_RESET}"
    printf '\nUbuntu         %s\n' "${ORYNQUIX_ACTUAL_UBUNTU_VERSION:-Detected at first install}"
    printf 'Linux user      %s\n' "$ORYNQUIX_USERNAME"
    printf 'Profile         %s\n' "$ORYNQUIX_PROFILE"
    printf 'Resolution      %s\n' "$ORYNQUIX_RESOLUTION"
    printf 'Desktop         XFCE\n'
    printf 'Display         :%s\n' "$ORYNQUIX_DEFAULT_DISPLAY"
    printf 'VNC port        %s\n' "$((5900 + ORYNQUIX_DEFAULT_DISPLAY))"
    printf '\nStart desktop:  orynquix start\n'
    printf 'Enter Ubuntu:   orynquix enter\n'
    printf 'System health:  orynquix doctor\n'
    printf '\nConnect your VNC viewer to 127.0.0.1:%s after starting the desktop.\n' "$((5900 + ORYNQUIX_DEFAULT_DISPLAY))"
}
