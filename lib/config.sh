#!/usr/bin/env bash

readonly ORYNQUIX_VERSION="0.2.0-alpha"
readonly ORYNQUIX_PRODUCT_REVISION="V3"
readonly ORYNQUIX_SCHEMA_VERSION="1"
readonly ORYNQUIX_DISTRIBUTION="ubuntu"
readonly ORYNQUIX_PREFERRED_UBUNTU="26.04"
readonly ORYNQUIX_DEFAULT_USER="orynquix"
readonly ORYNQUIX_DEFAULT_DISPLAY="1"
readonly ORYNQUIX_DEFAULT_RESOLUTION="1280x720"
readonly ORYNQUIX_DEFAULT_DEPTH="24"
readonly ORYNQUIX_DEV_TOOL_IDS='git,github-cli,python,node,java,cpp,cmake,clang,jupyter,databases,neovim'

ORYNQUIX_PROJECT_ROOT="${ORYNQUIX_PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
ORYNQUIX_HOME="${ORYNQUIX_HOME:-${HOME}/.orynquix}"
ORYNQUIX_STATE_DIR="${ORYNQUIX_STATE_DIR:-${ORYNQUIX_HOME}/state}"
ORYNQUIX_LOG_DIR="${ORYNQUIX_LOG_DIR:-${ORYNQUIX_HOME}/logs}"
ORYNQUIX_BACKUP_DIR="${ORYNQUIX_BACKUP_DIR:-${ORYNQUIX_HOME}/backups}"
ORYNQUIX_DATA_DIR="${ORYNQUIX_DATA_DIR:-${HOME}/.local/share/orynquix}"
ORYNQUIX_CONFIG_FILE="${ORYNQUIX_CONFIG_FILE:-${ORYNQUIX_HOME}/config.ini}"
ORYNQUIX_STATE_FILE="${ORYNQUIX_STATE_FILE:-${ORYNQUIX_STATE_DIR}/install-state}"
ORYNQUIX_LOCK_DIR="${ORYNQUIX_LOCK_DIR:-${ORYNQUIX_STATE_DIR}/install.lock}"

ORYNQUIX_PROFILE="${ORYNQUIX_PROFILE:-}"
ORYNQUIX_USERNAME="${ORYNQUIX_USERNAME:-$ORYNQUIX_DEFAULT_USER}"
ORYNQUIX_BROWSER="${ORYNQUIX_BROWSER:-}"
ORYNQUIX_EDITOR="${ORYNQUIX_EDITOR:-}"
ORYNQUIX_DEV_TOOLS="${ORYNQUIX_DEV_TOOLS:-}"
ORYNQUIX_AUDIO="${ORYNQUIX_AUDIO:-auto}"
ORYNQUIX_STORAGE="${ORYNQUIX_STORAGE:-auto}"
ORYNQUIX_RESOLUTION="${ORYNQUIX_RESOLUTION:-}"
ORYNQUIX_COMPOSITOR="${ORYNQUIX_COMPOSITOR:-auto}"
ORYNQUIX_UI_SCALE="${ORYNQUIX_UI_SCALE:-1.0}"

ORYNQUIX_VERBOSE="${ORYNQUIX_VERBOSE:-0}"
ORYNQUIX_QUIET="${ORYNQUIX_QUIET:-0}"
ORYNQUIX_DEBUG="${ORYNQUIX_DEBUG:-0}"
ORYNQUIX_DRY_RUN="${ORYNQUIX_DRY_RUN:-0}"
ORYNQUIX_NON_INTERACTIVE="${ORYNQUIX_NON_INTERACTIVE:-0}"
ORYNQUIX_ASSUME_YES="${ORYNQUIX_ASSUME_YES:-0}"
ORYNQUIX_RECONFIGURE="${ORYNQUIX_RECONFIGURE:-0}"
ORYNQUIX_LINUX_PASSWORD_FD="${ORYNQUIX_LINUX_PASSWORD_FD:-}"
ORYNQUIX_VNC_PASSWORD_FD="${ORYNQUIX_VNC_PASSWORD_FD:-}"

validate_enum() {
    local value=${1-}
    shift
    local allowed
    for allowed in "$@"; do
        [[ "$value" == "$allowed" ]] && return 0
    done
    return 1
}

validate_username() {
    local username=${1-}
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
    case "$username" in
        root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|_apt|nobody)
            return 1
            ;;
    esac
}

validate_resolution() {
    local value=${1-} width height
    [[ "$value" =~ ^([0-9]{3,5})x([0-9]{3,5})$ ]] || return 1
    width=${BASH_REMATCH[1]}
    height=${BASH_REMATCH[2]}
    (( width >= 640 && width <= 7680 && height >= 480 && height <= 4320 ))
}

validate_ui_scale() {
    validate_enum "${1-}" 1 1.0 1.25 1.5 2 2.0
}

validate_display_number() {
    [[ "${1-}" =~ ^[0-9]{1,2}$ ]] && (( 10#${1} >= 1 && 10#${1} <= 99 ))
}

validate_port() {
    [[ "${1-}" =~ ^[0-9]{4,5}$ ]] && (( 10#${1} >= 1024 && 10#${1} <= 65535 ))
}

validate_depth() {
    validate_enum "${1-}" 16 24 32
}

validate_profile() {
    validate_enum "${1-}" lite standard developer complete custom
}

validate_browser_choice() {
    validate_enum "${1-}" chromium firefox both none
}

validate_editor_choice() {
    validate_enum "${1-}" auto vscode code-server both none
}

validate_dev_tools_choice() {
    local value=${1-} csv item
    local -a items=()
    validate_enum "$value" none recommended full && return 0
    [[ "$value" == custom:* ]] || return 1
    csv=${value#custom:}
    [[ -n "$csv" && "$csv" != *, ]] || return 1
    IFS=',' read -r -a items <<<"$csv"
    for item in "${items[@]}"; do
        [[ -n "$item" && ",$ORYNQUIX_DEV_TOOL_IDS," == *",$item,"* ]] || return 1
    done
}

validate_tristate() {
    validate_enum "${1-}" auto true false
}

validate_compositor_choice() {
    validate_enum "${1-}" auto true false
}

normalize_arch() {
    case "${1-}" in
        aarch64|arm64) printf '%s\n' aarch64 ;;
        x86_64|amd64) printf '%s\n' x86_64 ;;
        armv7l|armv8l) printf '%s\n' arm ;;
        *) printf '%s\n' "${1-unknown}" ;;
    esac
}

config_get() {
    local section=$1 key=$2 file=${3:-$ORYNQUIX_CONFIG_FILE}
    [[ -r "$file" ]] || return 1
    awk -v wanted_section="$section" -v wanted_key="$key" '
        /^[[:space:]]*\[/ {
            current=$0
            gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", current)
            next
        }
        current == wanted_section && $0 ~ "^[[:space:]]*" wanted_key "[[:space:]]*=" {
            line=$0
            sub(/^[^=]*=[[:space:]]*/, "", line)
            sub(/[[:space:]]*$/, "", line)
            print line
            exit
        }
    ' "$file"
}
