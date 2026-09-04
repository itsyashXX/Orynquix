#!/usr/bin/env bash

readonly ORYNQUIX_TERMUX_PACKAGES=(
    proot-distro curl ca-certificates coreutils findutils gawk grep sed util-linux procps
)

install_termux_dependencies() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 && ! -x "${PREFIX:-}/bin/pkg" ]]; then
        log_info '[dry-run] Would refresh Termux repositories and install host dependencies'
        return 0
    fi
    run_visible_or_logged 'Refreshing Termux package metadata' "$ORYNQUIX_INSTALL_LOG" \
        pkg update -y -q
    run_visible_or_logged 'Installing Termux host components' "$ORYNQUIX_INSTALL_LOG" \
        pkg install -y -q "${ORYNQUIX_TERMUX_PACKAGES[@]}"
}

verify_termux_dependencies() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    local command
    for command in proot-distro curl awk sed grep; do
        command -v "$command" >/dev/null 2>&1 || return 1
    done
}

install_orynquix_cli() {
    local releases_dir="$ORYNQUIX_DATA_DIR/app/releases"
    local release_dir="$releases_dir/$ORYNQUIX_VERSION"
    local temporary_dir
    local current_link="$ORYNQUIX_DATA_DIR/app/current"
    local bin_dir="${PREFIX:-$HOME/.local}/bin"

    if [[ "$ORYNQUIX_DRY_RUN" == 1 ]]; then
        log_info "[dry-run] Would install the Orynquix CLI into $bin_dir"
        return 0
    fi

    mkdir -p -- "$releases_dir" "$bin_dir"
    temporary_dir=$(mktemp -d "$releases_dir/.${ORYNQUIX_VERSION}.tmp.XXXXXX")
    cp -a -- "$ORYNQUIX_PROJECT_ROOT/bin" "$ORYNQUIX_PROJECT_ROOT/lib" \
        "$ORYNQUIX_PROJECT_ROOT/installer" "$ORYNQUIX_PROJECT_ROOT/config" \
        "$ORYNQUIX_PROJECT_ROOT/rootfs" "$temporary_dir/"
    printf '%s\n' "$ORYNQUIX_VERSION" >"$temporary_dir/VERSION"
    chmod +x -- "$temporary_dir/bin/orynquix"

    if [[ -d "$release_dir" ]]; then
        local previous_dir="${release_dir}.previous.$(date -u +%Y%m%dT%H%M%SZ)"
        mv -- "$release_dir" "$previous_dir"
    fi
    mv -- "$temporary_dir" "$release_dir"
    ln -sfn -- "$release_dir" "${current_link}.new"
    mv -Tf -- "${current_link}.new" "$current_link"
    ln -sfn -- "$current_link/bin/orynquix" "$bin_dir/orynquix"
    log_success "Orynquix CLI installed"
}

verify_orynquix_cli() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    local bin_dir="${PREFIX:-$HOME/.local}/bin"
    [[ -x "$bin_dir/orynquix" ]] &&
        [[ "$("$bin_dir/orynquix" version 2>/dev/null)" == "Orynquix $ORYNQUIX_VERSION" ]]
}
