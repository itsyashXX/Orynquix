#!/usr/bin/env bash

load_access_settings() {
    ORYNQUIX_VIEWER=$(config_get access viewer)
    ORYNQUIX_WEB_PORT=$(config_get access web_port)
    ORYNQUIX_ACCESS_LOCALHOST=$(config_get access localhost)
    validate_viewer_choice "$ORYNQUIX_VIEWER" &&
        validate_port "$ORYNQUIX_WEB_PORT" &&
        [[ "$ORYNQUIX_ACCESS_LOCALHOST" == true ]] || {
            log_error 'Desktop-access configuration contains an invalid value.'
            return 1
        }
}

browser_access_enabled() {
    [[ "$ORYNQUIX_VIEWER" == browser || "$ORYNQUIX_VIEWER" == both ]]
}

configure_desktop_access() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && {
        log_info "[dry-run] Would configure $ORYNQUIX_VIEWER desktop access"
        return 0
    }
    load_access_settings
    if ! browser_access_enabled; then
        log_success 'VNC-app access selected; browser proxy is not required'
        return 0
    fi
    verify_packages_available novnc websockify
    run_visible_or_logged 'Installing localhost browser desktop access' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y -q \
            novnc websockify
    atomic_install_in_ubuntu /usr/local/libexec/orynquix/web-session 0755 root:root \
        <"$ORYNQUIX_PROJECT_ROOT/rootfs/scripts/web-session.sh"
}

verify_desktop_access() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    load_access_settings || return 1
    browser_access_enabled || return 0
    run_in_ubuntu /usr/bin/test -x /usr/local/libexec/orynquix/web-session &&
        run_in_ubuntu /bin/sh -c 'command -v websockify >/dev/null 2>&1' &&
        run_in_ubuntu /usr/bin/test -r /usr/share/novnc/vnc.html
}

web_backend() {
    local action=$1
    load_access_settings
    load_vnc_settings
    run_as_ubuntu_user "$ORYNQUIX_USERNAME" /usr/bin/env \
        HOME="$(vnc_home)" USER="$ORYNQUIX_USERNAME" LOGNAME="$ORYNQUIX_USERNAME" \
        /usr/local/libexec/orynquix/web-session "$action" "$ORYNQUIX_WEB_PORT" "$ORYNQUIX_VNC_PORT"
}

web_start() {
    local output
    output=$(web_backend start) || return
    printf '%s\n' "$output"
    printf '\nBrowser desktop: http://127.0.0.1:%s/vnc.html?autoconnect=true&resize=scale\n' "$ORYNQUIX_WEB_PORT"
}

web_stop() { web_backend stop; }
web_status() { web_backend status; }

desktop_start() {
    load_access_settings
    vnc_start
    if browser_access_enabled; then
        if ! web_start; then
            log_error 'The VNC desktop started, but browser access did not become healthy.'
            log_error 'Use a VNC app or inspect: orynquix logs web'
            return 1
        fi
    fi
}

desktop_stop() {
    load_access_settings
    if run_in_ubuntu /usr/bin/test -x /usr/local/libexec/orynquix/web-session; then
        web_stop || return
    fi
    vnc_stop
}

desktop_restart() {
    desktop_stop
    desktop_start
}
