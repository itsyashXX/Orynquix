#!/usr/bin/env bash

command_exists() { command -v "$1" >/dev/null 2>&1; }

validate_termux_environment() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 && ! -x "${PREFIX:-}/bin/pkg" ]]; then
        log_warn "Not running in Termux; dry-run will stop before device mutations."
        return 0
    fi

    [[ -n "${PREFIX:-}" && -x "$PREFIX/bin/pkg" ]] || {
        log_error "Orynquix must be installed from the Termux host shell."
        return 1
    }
    case "$PREFIX" in
        /data/data/*/files/usr) ;;
        *) log_warn "Unusual Termux prefix detected: $PREFIX" ;;
    esac
    command_exists bash || { log_error "bash is required."; return 1; }
    command_exists pkg || { log_error "The Termux pkg command is unavailable."; return 1; }
    log_success "Termux host environment detected"
}

verify_termux_environment() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    [[ -n "${PREFIX:-}" && -x "$PREFIX/bin/pkg" ]]
}
