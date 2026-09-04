#!/usr/bin/env bash

secure_mkdir() {
    local path=$1 mode=${2:-700}
    mkdir -p -- "$path"
    chmod "$mode" -- "$path"
}

validate_managed_path() {
    local path=${1-} resolved parent
    [[ -n "$path" && "$path" == /* ]] || return 1
    [[ "$path" != / && "$path" != "$HOME" && "$path" != "${PREFIX:-/__unset__}" ]] || return 1
    parent=$(dirname -- "$path")
    [[ -d "$parent" ]] || return 1
    resolved=$(cd -- "$parent" && pwd -P)/$(basename -- "$path")
    case "$resolved" in
        "$ORYNQUIX_HOME"/*|"$ORYNQUIX_DATA_DIR"/*) return 0 ;;
        *) return 1 ;;
    esac
}

atomic_write() {
    local target=$1 mode=${2:-600} directory temporary backup
    directory=$(dirname -- "$target")
    mkdir -p -- "$directory"
    temporary=$(mktemp "${directory}/.orynquix.tmp.XXXXXX")
    chmod "$mode" -- "$temporary"
    cat >"$temporary"

    [[ -s "$temporary" ]] || {
        rm -f -- "$temporary"
        log_error "Refusing to install an empty configuration: $target"
        return 1
    }

    if [[ -e "$target" ]]; then
        backup="${target}.previous"
        cp -p -- "$target" "$backup"
    fi
    mv -f -- "$temporary" "$target"
    chmod "$mode" -- "$target"
}

safe_remove_managed_file() {
    local path=$1
    validate_managed_path "$path" || {
        log_error "Refusing to remove unmanaged path: $path"
        return 1
    }
    [[ ! -d "$path" ]] || {
        log_error "Refusing to remove a directory through the file removal helper: $path"
        return 1
    }
    rm -f -- "$path"
}

ini_set_value() {
    local file=$1 section=$2 key=$3 value=$4 temporary
    [[ "$section" =~ ^[a-z0-9_]+$ && "$key" =~ ^[a-z0-9_]+$ && "$value" != *$'\n'* ]] || {
        log_error 'Invalid INI update request.'
        return 1
    }
    [[ -r "$file" ]] || { log_error "Configuration is unavailable: $file"; return 1; }
    temporary=$(mktemp "$(dirname -- "$file")/.orynquix.ini.XXXXXX")
    awk -v wanted_section="$section" -v wanted_key="$key" -v replacement="$value" '
        /^[[:space:]]*\[/ {
            current=$0
            gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", current)
        }
        current == wanted_section && $0 ~ "^[[:space:]]*" wanted_key "[[:space:]]*=" {
            print wanted_key "=" replacement
            changed=1
            next
        }
        { print }
        END { if (!changed) exit 3 }
    ' "$file" >"$temporary" || {
        rm -f -- "$temporary"
        log_error "Configuration key was not found: [$section] $key"
        return 1
    }
    atomic_write "$file" 600 <"$temporary"
    rm -f -- "$temporary"
}
