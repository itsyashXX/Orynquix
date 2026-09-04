#!/usr/bin/env bash

if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
    readonly C_RESET=$'\033[0m'
    readonly C_BOLD=$'\033[1m'
    readonly C_DIM=$'\033[2m'
    readonly C_GREEN=$'\033[32m'
    readonly C_YELLOW=$'\033[33m'
    readonly C_RED=$'\033[31m'
    readonly C_BLUE=$'\033[36m'
else
    readonly C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_YELLOW='' C_RED='' C_BLUE=''
fi

log_info() { [[ "${ORYNQUIX_QUIET:-0}" == 1 ]] || printf '%s→%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_success() { [[ "${ORYNQUIX_QUIET:-0}" == 1 ]] || printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_error() { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
log_debug() { [[ "${ORYNQUIX_DEBUG:-0}" == 1 ]] && printf '%sdebug:%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2 || true; }

show_banner() {
    [[ "${ORYNQUIX_QUIET:-0}" == 1 ]] && return 0
    printf '%s\n' "${C_BOLD}╭────────────────────────────────────────────────────────────╮"
    printf '%s\n' "│                         ORYNQUIX                           │"
    printf '%s\n' "│              Ubuntu Desktop for Android                   │"
    printf '%s\n' "╰────────────────────────────────────────────────────────────╯${C_RESET}"
    printf 'Version %s\n\n' "$ORYNQUIX_VERSION"
}

print_kv() {
    printf '  %-18s %s\n' "$1" "${2:-Unavailable}"
}

format_duration() {
    local total=${1:-0}
    if (( total >= 60 )); then
        printf '%dm %02ds' "$((total / 60))" "$((total % 60))"
    else
        printf '%ds' "$total"
    fi
}

run_visible_or_logged() {
    local label=$1 log_file=$2
    shift 2
    local started=$SECONDS rc=0 pid frame_index=0
    local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

    if [[ "${ORYNQUIX_DRY_RUN:-0}" == 1 ]]; then
        log_info "[dry-run] $label"
        return 0
    fi

    mkdir -p -- "$(dirname -- "$log_file")"
    if [[ "${ORYNQUIX_VERBOSE:-0}" == 1 ]]; then
        log_info "$label"
        "$@" > >(tee -a "$log_file") 2> >(tee -a "$log_file" >&2)
        return
    fi

    "$@" >>"$log_file" 2>&1 &
    pid=$!
    if [[ -t 1 && "${ORYNQUIX_QUIET:-0}" != 1 && "${ORYNQUIX_TEST_MODE:-0}" != 1 ]]; then
        while kill -0 "$pid" 2>/dev/null; do
            printf '\r  %s %s  %s' "${frames[$frame_index]}" "$label" "$(format_duration "$((SECONDS - started))")"
            frame_index=$(((frame_index + 1) % ${#frames[@]}))
            sleep 0.12
        done
        wait "$pid" || rc=$?
        printf '\r%*s\r' "$(( ${#label} + 20 ))" ''
    else
        [[ "${ORYNQUIX_QUIET:-0}" == 1 ]] || printf '  → %s\n' "$label"
        wait "$pid" || rc=$?
    fi

    if (( rc != 0 )); then
        log_error "$label failed (exit $rc)."
        printf '  Log: %s\n' "$log_file" >&2
        return "$rc"
    fi
    log_success "$label ($(format_duration "$((SECONDS - started))"))"
}

stage_heading() {
    local index=$1 total=$2 label=$3 percent
    percent=$((index * 100 / total))
    [[ "${ORYNQUIX_QUIET:-0}" == 1 ]] || printf '\n%s[%02d/%02d · %3d%%]%s %s\n' "$C_BOLD" "$index" "$total" "$percent" "$C_RESET" "$label"
}

prompt_yes_no() {
    local prompt=$1 default=${2:-yes} reply suffix
    [[ "$default" == yes ]] && suffix='[Y/n]' || suffix='[y/N]'
    while true; do
        read -r -p "$prompt $suffix " reply
        reply=${reply:-$default}
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) printf 'Please enter yes or no.\n' ;;
        esac
    done
}

prompt_menu() {
    local __result_var=$1 prompt=$2 default=$3
    shift 3
    local __orynquix_menu_selection option_count=$#
    while true; do
        printf '\n%s\n' "$prompt"
        printf '%s\n' "$@"
        read -r -p "Choose [$default]: " __orynquix_menu_selection
        __orynquix_menu_selection=${__orynquix_menu_selection:-$default}
        if [[ "$__orynquix_menu_selection" =~ ^[0-9]{1,3}$ ]] &&
            (( 10#$__orynquix_menu_selection >= 1 && 10#$__orynquix_menu_selection <= option_count )); then
            printf -v "$__result_var" '%s' "$((10#$__orynquix_menu_selection))"
            return 0
        fi
        printf 'Choose a number from 1 to %d.\n' "$option_count"
    done
}
