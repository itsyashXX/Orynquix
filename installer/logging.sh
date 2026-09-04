#!/usr/bin/env bash

init_logging() {
    secure_mkdir "$ORYNQUIX_LOG_DIR" 700
    ORYNQUIX_INSTALL_LOG="$ORYNQUIX_LOG_DIR/install.log"
    touch -- "$ORYNQUIX_INSTALL_LOG"
    chmod 600 -- "$ORYNQUIX_INSTALL_LOG"
    printf '\n[%s] Orynquix %s installer started (PID %s)\n' \
        "$(date -u +%FT%TZ)" "$ORYNQUIX_VERSION" "$$" >>"$ORYNQUIX_INSTALL_LOG"
}

redact_log_stream() {
    sed -E \
        -e 's/([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt])=([^[:space:]]+)/\1=[REDACTED]/g' \
        -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1[REDACTED]@#g'
}

record_failure_context() {
    local exit_code=$1 line=$2 command=${3-unknown}
    {
        printf '[%s] FAILURE exit=%s line=%s command=' "$(date -u +%FT%TZ)" "$exit_code" "$line"
        printf '%q ' "$command"
        printf '\n'
    } | redact_log_stream >>"$ORYNQUIX_INSTALL_LOG"
}
