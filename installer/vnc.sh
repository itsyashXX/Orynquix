#!/usr/bin/env bash

vnc_home() { printf '/home/%s\n' "$ORYNQUIX_USERNAME"; }
vnc_password_path() { printf '%s/.config/tigervnc/passwd\n' "$(vnc_home)"; }
vnc_xstartup_path() { printf '%s/.local/share/orynquix/vnc/xstartup\n' "$(vnc_home)"; }

load_vnc_settings() {
    ORYNQUIX_VNC_DISPLAY=$(config_get vnc display)
    ORYNQUIX_VNC_PORT=$(config_get vnc port)
    ORYNQUIX_VNC_RESOLUTION=$(config_get vnc resolution)
    ORYNQUIX_VNC_DEPTH=$(config_get vnc depth)
    ORYNQUIX_VNC_LOCALHOST=$(config_get vnc localhost)
    validate_display_number "$ORYNQUIX_VNC_DISPLAY" &&
        validate_port "$ORYNQUIX_VNC_PORT" &&
        validate_resolution "$ORYNQUIX_VNC_RESOLUTION" &&
        validate_depth "$ORYNQUIX_VNC_DEPTH" &&
        validate_enum "$ORYNQUIX_VNC_LOCALHOST" true false || {
            log_error 'VNC configuration contains an invalid value.'
            return 1
        }
    (( ORYNQUIX_VNC_PORT == 5900 + ORYNQUIX_VNC_DISPLAY )) || {
        log_error 'VNC port must equal 5900 + display number.'
        return 1
    }
    [[ "$ORYNQUIX_VNC_LOCALHOST" == true ]] || {
        log_error 'LAN VNC is not enabled in this phase; localhost=true is required.'
        return 1
    }
}

install_vnc_packages() {
    local packages=(tigervnc-standalone-server tigervnc-tools procps)
    verify_packages_available "${packages[@]}"
    run_visible_or_logged 'Installing TigerVNC components' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y -q "${packages[@]}"
}

install_vnc_runtime_files() {
    local home owner
    home=$(vnc_home)
    owner="$ORYNQUIX_USERNAME:$ORYNQUIX_USERNAME"
    atomic_install_in_ubuntu /usr/local/libexec/orynquix/vnc-session 0755 root:root \
        <"$ORYNQUIX_PROJECT_ROOT/rootfs/scripts/vnc-session.sh"
    atomic_install_in_ubuntu "$home/.local/share/orynquix/vnc/xstartup" 0755 "$owner" \
        <"$ORYNQUIX_PROJECT_ROOT/rootfs/templates/xstartup"
    write_vnc_user_config
}

write_vnc_user_config() {
    local home owner
    home=$(vnc_home)
    owner="$ORYNQUIX_USERNAME:$ORYNQUIX_USERNAME"
    load_vnc_settings
    cat <<EOF | atomic_install_in_ubuntu "$home/.config/orynquix/vnc.ini" 0600 "$owner"
[vnc]
display=$ORYNQUIX_VNC_DISPLAY
port=$ORYNQUIX_VNC_PORT
resolution=$ORYNQUIX_VNC_RESOLUTION
depth=$ORYNQUIX_VNC_DEPTH
localhost=true
xstartup=$(vnc_xstartup_path)
EOF
}

validate_vnc_password_value() {
    local password=${1-}
    local LC_ALL=C
    (( ${#password} >= 6 && ${#password} <= 8 )) || {
        log_error 'TigerVNC passwords must contain 6–8 characters.'
        return 1
    }
    [[ "$password" != *[$'\t\r\n']* ]] || {
        log_error 'The VNC password cannot contain tabs or line breaks.'
        return 1
    }
}

read_vnc_password() {
    local first second
    if [[ -n "$ORYNQUIX_VNC_PASSWORD_FD" ]]; then
        read -r -u "$ORYNQUIX_VNC_PASSWORD_FD" first || return 1
        validate_vnc_password_value "$first" || return 1
        ORYNQUIX_VNC_PASSWORD=$first
        return 0
    fi
    [[ "$ORYNQUIX_NON_INTERACTIVE" != 1 ]] || {
        log_error 'Initial VNC setup in non-interactive mode requires --vnc-password-fd N.'
        return 64
    }
    while true; do
        read -r -s -p 'Create desktop (VNC) password, 6–8 characters: ' first; printf '\n'
        read -r -s -p 'Confirm desktop password: ' second; printf '\n'
        validate_vnc_password_value "$first" || continue
        [[ "$first" == "$second" ]] || { printf 'Passwords do not match.\n'; continue; }
        ORYNQUIX_VNC_PASSWORD=$first
        return 0
    done
}

vnc_password_is_valid() {
    local path
    path=$(vnc_password_path)
    run_in_ubuntu /usr/bin/test -s "$path" &&
        [[ "$(run_in_ubuntu /usr/bin/stat -c %a "$path" 2>/dev/null)" == 600 ]] &&
        [[ "$(run_in_ubuntu /usr/bin/stat -c %U "$path" 2>/dev/null)" == "$ORYNQUIX_USERNAME" ]]
}

configure_vnc_password() {
    local force=${1:-false} path home owner password_command
    path=$(vnc_password_path)
    home=$(vnc_home)
    owner="$ORYNQUIX_USERNAME:$ORYNQUIX_USERNAME"
    if [[ "$force" != true ]] && vnc_password_is_valid; then
        log_success 'Existing VNC password is valid; preserving it'
        return 0
    fi
    read_vnc_password
    if run_in_ubuntu /bin/sh -c 'command -v tigervncpasswd >/dev/null 2>&1'; then
        password_command=tigervncpasswd
    else
        password_command=vncpasswd
    fi
    printf '%s\n' "$ORYNQUIX_VNC_PASSWORD" | run_as_ubuntu_user "$ORYNQUIX_USERNAME" /bin/sh -c '
        set -eu
        home=$1
        destination=$2
        password_command=$3
        directory=${destination%/*}
        temporary="${directory}/.passwd.$$.tmp"
        mkdir -p "$directory"
        chmod 700 "$directory"
        umask 077
        trap '\''rm -f "$temporary"'\'' EXIT HUP INT TERM
        "$password_command" -f >"$temporary"
        test -s "$temporary"
        chmod 600 "$temporary"
        mv -f "$temporary" "$destination"
        trap - EXIT HUP INT TERM
    ' orynquix-vnc-password "$home" "$path" "$password_command"
    unset ORYNQUIX_VNC_PASSWORD
    run_in_ubuntu /bin/chown "$owner" "$path"
    vnc_password_is_valid
    log_success 'VNC password configured securely'
}

configure_vnc() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 ]]; then
        log_info '[dry-run] Would install TigerVNC, create private authentication, and configure XFCE startup'
        return 0
    fi
    load_vnc_settings
    install_vnc_packages
    install_vnc_runtime_files
    configure_vnc_password false
}

verify_vnc_configuration() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    local home
    home=$(vnc_home)
    load_vnc_settings &&
        run_in_ubuntu /usr/bin/test -x /usr/local/libexec/orynquix/vnc-session &&
        run_in_ubuntu /usr/bin/test -x "$(vnc_xstartup_path)" &&
        run_in_ubuntu /usr/bin/test -s "$home/.config/orynquix/vnc.ini" &&
        run_in_ubuntu /bin/sh -c 'command -v tigervncserver >/dev/null 2>&1 || command -v vncserver >/dev/null 2>&1' &&
        run_in_ubuntu /bin/sh -c 'command -v dbus-launch >/dev/null 2>&1 && command -v xfce4-session >/dev/null 2>&1' &&
        vnc_password_is_valid
}

vnc_backend() {
    local action=$1
    load_vnc_settings
    run_as_ubuntu_user "$ORYNQUIX_USERNAME" /usr/bin/env \
        HOME="$(vnc_home)" USER="$ORYNQUIX_USERNAME" LOGNAME="$ORYNQUIX_USERNAME" \
        /usr/local/libexec/orynquix/vnc-session "$action" "$ORYNQUIX_VNC_DISPLAY" \
        "$ORYNQUIX_VNC_RESOLUTION" "$ORYNQUIX_VNC_DEPTH"
}

vnc_start() {
    local output
    if output=$(vnc_backend start); then
        printf '%s\n' "$output"
        printf '\nConnect to: 127.0.0.1:%s\n' "$ORYNQUIX_VNC_PORT"
        printf 'Display:    :%s\n' "$ORYNQUIX_VNC_DISPLAY"
        printf 'Resolution: %s\n' "$ORYNQUIX_VNC_RESOLUTION"
        return 0
    fi
    return 1
}

vnc_stop() { vnc_backend stop; }

vnc_status() {
    local output rc=0
    output=$(vnc_backend status) || rc=$?
    printf '%s\n' "$output"
    return "$rc"
}

vnc_restart() {
    vnc_stop
    vnc_start
}

vnc_set_resolution() {
    local resolution=$1 previous_resolution
    validate_resolution "$resolution" || {
        log_error 'Resolution must be WIDTHxHEIGHT within 640x480–7680x4320.'
        return 64
    }
    previous_resolution=$(config_get vnc resolution)
    ini_set_value "$ORYNQUIX_CONFIG_FILE" vnc resolution "$resolution"
    ORYNQUIX_VNC_RESOLUTION=$resolution
    if ! write_vnc_user_config; then
        if [[ -r "${ORYNQUIX_CONFIG_FILE}.previous" ]]; then
            cp -p -- "${ORYNQUIX_CONFIG_FILE}.previous" "$ORYNQUIX_CONFIG_FILE"
        fi
        ORYNQUIX_VNC_RESOLUTION=$previous_resolution
        log_error 'Unable to update the Ubuntu VNC configuration; the host configuration was rolled back.'
        return 1
    fi
    log_success "VNC resolution changed to $resolution"
    if vnc_status >/dev/null 2>&1; then
        log_warn 'Restart the desktop to apply the new resolution: orynquix restart'
    fi
}
