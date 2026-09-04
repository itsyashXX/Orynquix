#!/usr/bin/env bash

dns_works() {
    if command -v getent >/dev/null 2>&1; then
        getent ahosts github.com >/dev/null 2>&1
    elif command -v nslookup >/dev/null 2>&1; then
        nslookup github.com >/dev/null 2>&1
    else
        return 2
    fi
}

https_works() {
    if command -v curl >/dev/null 2>&1; then
        curl --fail --silent --show-error --location --max-time 15 --output /dev/null https://github.com/
    elif command -v wget >/dev/null 2>&1; then
        wget --quiet --spider --timeout=15 https://github.com/
    elif command -v git >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/itsyashxx/orynquix.git HEAD >/dev/null 2>&1
    else
        return 2
    fi
}

check_network() {
    if [[ "$ORYNQUIX_DRY_RUN" == 1 && ! -x "${PREFIX:-}/bin/pkg" ]]; then
        log_warn "Network mutation checks skipped outside Termux dry-run."
        return 0
    fi
    local dns_status=0
    dns_works || dns_status=$?
    if (( dns_status == 2 )); then
        log_warn 'A standalone DNS probe is unavailable; HTTPS will still verify name resolution.'
    elif (( dns_status != 0 )); then
        log_error "Network may be connected, but DNS resolution for github.com failed."
        printf '%s\n' 'Check Android Private DNS, VPN settings, and Wi-Fi/mobile data.' >&2
        return 1
    else
        log_success "DNS resolution works"
    fi
    if ! retry_command 3 2 'HTTPS reachability' https_works; then
        log_error "HTTPS connection to github.com failed. Installation state was preserved."
        return 1
    fi
    log_success "HTTPS connectivity works"
}

verify_network() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    local dns_status=0
    dns_works || dns_status=$?
    (( dns_status == 0 || dns_status == 2 )) && https_works
}
