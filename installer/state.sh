#!/usr/bin/env bash

declare -Ag ORYNQUIX_STAGE_STATE=()

load_state() {
    local key value
    ORYNQUIX_STAGE_STATE=()
    [[ -r "$ORYNQUIX_STATE_FILE" ]] || return 0
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[a-z0-9_]+$ ]] || continue
        [[ "$value" == complete ]] || continue
        ORYNQUIX_STAGE_STATE["$key"]=$value
    done <"$ORYNQUIX_STATE_FILE"
}

save_state() {
    local key
    {
        for key in "${!ORYNQUIX_STAGE_STATE[@]}"; do
            printf '%s=%s\n' "$key" "${ORYNQUIX_STAGE_STATE[$key]}"
        done | LC_ALL=C sort
    } | atomic_write "$ORYNQUIX_STATE_FILE" 600
}

stage_completed() {
    [[ "${ORYNQUIX_STAGE_STATE[${1-}]:-}" == complete ]]
}

mark_stage_complete() {
    local stage=$1
    [[ "$stage" =~ ^[a-z0-9_]+$ ]] || {
        log_error "Invalid installer stage key: $stage"
        return 1
    }
    ORYNQUIX_STAGE_STATE["$stage"]=complete
    save_state
    log_success "Stage verified and saved"
}
