#!/usr/bin/env bash

acquire_install_lock() {
    local owner_file="$ORYNQUIX_LOCK_DIR/owner" owner_pid owner_started
    mkdir -p -- "$ORYNQUIX_STATE_DIR"
    if mkdir -- "$ORYNQUIX_LOCK_DIR" 2>/dev/null; then
        printf '%s\n%s\n' "$$" "$(date -u +%FT%TZ)" >"$owner_file"
        ORYNQUIX_LOCK_HELD=1
        return 0
    fi

    if [[ -r "$owner_file" ]]; then
        read -r owner_pid <"$owner_file" || owner_pid=''
        owner_started=$(sed -n '2p' "$owner_file" 2>/dev/null || true)
        if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
            log_error "Another installer is running (PID $owner_pid, started ${owner_started:-unknown})."
            return 1
        fi
    fi

    log_warn "Recovering a stale installer lock."
    rm -f -- "$owner_file"
    rmdir -- "$ORYNQUIX_LOCK_DIR" 2>/dev/null || {
        log_error "The installer lock is not safe to recover automatically: $ORYNQUIX_LOCK_DIR"
        return 1
    }
    mkdir -- "$ORYNQUIX_LOCK_DIR"
    printf '%s\n%s\n' "$$" "$(date -u +%FT%TZ)" >"$owner_file"
    ORYNQUIX_LOCK_HELD=1
}

release_install_lock() {
    [[ "${ORYNQUIX_LOCK_HELD:-0}" == 1 ]] || return 0
    rm -f -- "$ORYNQUIX_LOCK_DIR/owner"
    rmdir -- "$ORYNQUIX_LOCK_DIR" 2>/dev/null || true
    ORYNQUIX_LOCK_HELD=0
}

retry_command() {
    local attempts=$1 initial_delay=$2 label=$3
    shift 3
    local try=1 delay=$initial_delay rc=0
    while (( try <= attempts )); do
        "$@" && return 0
        rc=$?
        (( try == attempts )) && break
        log_warn "$label failed (attempt $try/$attempts); retrying in ${delay}s."
        sleep "$delay"
        delay=$((delay * 2))
        ((try++))
    done
    return "$rc"
}
