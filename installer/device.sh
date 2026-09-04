#!/usr/bin/env bash

metric_or_unavailable() {
    local value=${1-}
    [[ -n "$value" ]] && printf '%s\n' "$value" || printf '%s\n' 'Unavailable'
}

bytes_to_gib() {
    awk -v bytes="${1:-0}" 'BEGIN { printf "%.1f GiB", bytes / 1073741824 }'
}

kib_to_gib() {
    awk -v kib="${1:-0}" 'BEGIN { printf "%.1f GiB", kib / 1048576 }'
}

get_android_property() {
    command -v getprop >/dev/null 2>&1 || return 0
    getprop "$1" 2>/dev/null | tr -d '\r' | head -n 1
}

detect_battery() {
    local json
    command -v termux-battery-status >/dev/null 2>&1 || return 0
    json=$(timeout 3 termux-battery-status 2>/dev/null || true)
    [[ -n "$json" ]] || return 0
    if command -v jq >/dev/null 2>&1; then
        jq -r 'if .percentage == null then empty else (.percentage|tostring) + "%" end' <<<"$json" 2>/dev/null
    else
        sed -nE 's/.*"percentage"[[:space:]]*:[[:space:]]*([0-9]+).*/\1%/p' <<<"$json" | head -n 1
    fi
}

detect_thermal_state() {
    local zone type temp hottest='' hottest_value=0 raw value
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r "$zone/temp" ]] || continue
        type=$(cat "$zone/type" 2>/dev/null || true)
        [[ "$type" =~ (cpu|soc|battery|skin|ap|gpu) ]] || continue
        raw=$(cat "$zone/temp" 2>/dev/null || true)
        [[ "$raw" =~ ^[0-9]+$ ]] || continue
        value=$raw
        (( value > 1000 )) && value=$((value / 1000))
        if (( value > hottest_value && value < 150 )); then
            hottest_value=$value
            hottest="${value}°C"
        fi
    done
    printf '%s' "$hottest"
}

detect_termux_version() {
    local version
    if command -v termux-info >/dev/null 2>&1; then
        version=$(termux-info 2>/dev/null | sed -nE 's/^TERMUX_VERSION=//p' | head -n1)
    fi
    if [[ -z "${version:-}" && -n "${TERMUX_VERSION:-}" ]]; then
        version=$TERMUX_VERSION
    fi
    printf '%s' "${version:-}"
}

detect_device() {
    local mem_total_kib mem_available_kib storage_line storage_kib storage_total_kib
    ORYNQUIX_DEVICE_MANUFACTURER=$(get_android_property ro.product.manufacturer)
    ORYNQUIX_DEVICE_MODEL=$(get_android_property ro.product.model)
    ORYNQUIX_ANDROID_VERSION=$(get_android_property ro.build.version.release)
    ORYNQUIX_ANDROID_SDK=$(get_android_property ro.build.version.sdk)
    ORYNQUIX_ARCH=$(normalize_arch "$(uname -m 2>/dev/null || true)")
    ORYNQUIX_CPU_CORES=$(command -v nproc >/dev/null 2>&1 && nproc 2>/dev/null || true)
    mem_total_kib=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
    mem_available_kib=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
    ORYNQUIX_MEMORY_TOTAL=$([[ -n "$mem_total_kib" ]] && kib_to_gib "$mem_total_kib" || true)
    ORYNQUIX_MEMORY_AVAILABLE=$([[ -n "$mem_available_kib" ]] && kib_to_gib "$mem_available_kib" || true)

    storage_line=$(df -Pk "${PREFIX:-$HOME}" 2>/dev/null | awk 'NR==2 {print $2, $4}' || true)
    read -r storage_total_kib storage_kib <<<"$storage_line"
    ORYNQUIX_STORAGE_TOTAL=$([[ "${storage_total_kib:-}" =~ ^[0-9]+$ ]] && kib_to_gib "$storage_total_kib" || true)
    ORYNQUIX_STORAGE_FREE=$([[ "${storage_kib:-}" =~ ^[0-9]+$ ]] && kib_to_gib "$storage_kib" || true)
    ORYNQUIX_STORAGE_FREE_KIB=${storage_kib:-0}
    ORYNQUIX_KERNEL=$(uname -r 2>/dev/null || true)
    ORYNQUIX_TERMUX_VERSION=$(detect_termux_version)
    ORYNQUIX_SHELL_NAME=$(basename -- "${SHELL:-bash}")
    ORYNQUIX_BATTERY=$(detect_battery)
    ORYNQUIX_THERMAL=$(detect_thermal_state)

    recommend_device_profile "$mem_total_kib"
}

recommend_device_profile() {
    local mem_total_kib=${1:-0}
    if (( mem_total_kib > 0 && mem_total_kib < 4194304 )); then
        ORYNQUIX_RECOMMENDED_PROFILE=lite
        ORYNQUIX_RECOMMENDED_RESOLUTION=1024x600
        ORYNQUIX_RECOMMENDED_COMPOSITOR=false
    elif (( mem_total_kib > 0 && mem_total_kib < 6291456 )); then
        ORYNQUIX_RECOMMENDED_PROFILE=standard
        ORYNQUIX_RECOMMENDED_RESOLUTION=1280x720
        ORYNQUIX_RECOMMENDED_COMPOSITOR=auto
    elif (( mem_total_kib >= 6291456 )); then
        ORYNQUIX_RECOMMENDED_PROFILE=developer
        ORYNQUIX_RECOMMENDED_RESOLUTION=1280x720
        ORYNQUIX_RECOMMENDED_COMPOSITOR=true
    else
        ORYNQUIX_RECOMMENDED_PROFILE=standard
        ORYNQUIX_RECOMMENDED_RESOLUTION=1280x720
        ORYNQUIX_RECOMMENDED_COMPOSITOR=auto
    fi
}

show_device_information() {
    printf '\n%sDEVICE INFORMATION%s\n\n' "$C_BOLD" "$C_RESET"
    print_kv Manufacturer "$(metric_or_unavailable "$ORYNQUIX_DEVICE_MANUFACTURER")"
    print_kv Model "$(metric_or_unavailable "$ORYNQUIX_DEVICE_MODEL")"
    print_kv Android "$(metric_or_unavailable "$ORYNQUIX_ANDROID_VERSION")"
    print_kv SDK "$(metric_or_unavailable "$ORYNQUIX_ANDROID_SDK")"
    print_kv Architecture "$(metric_or_unavailable "$ORYNQUIX_ARCH")"
    print_kv CPU "${ORYNQUIX_CPU_CORES:+$ORYNQUIX_CPU_CORES cores}"
    print_kv Memory "$(metric_or_unavailable "$ORYNQUIX_MEMORY_TOTAL")"
    print_kv 'Available RAM' "$(metric_or_unavailable "$ORYNQUIX_MEMORY_AVAILABLE")"
    print_kv 'Storage Free' "$(metric_or_unavailable "$ORYNQUIX_STORAGE_FREE")"
    print_kv 'Storage Total' "$(metric_or_unavailable "$ORYNQUIX_STORAGE_TOTAL")"
    print_kv Kernel "$(metric_or_unavailable "$ORYNQUIX_KERNEL")"
    print_kv Termux "$(metric_or_unavailable "$ORYNQUIX_TERMUX_VERSION")"
    print_kv Shell "$(metric_or_unavailable "$ORYNQUIX_SHELL_NAME")"
    print_kv Battery "$(metric_or_unavailable "$ORYNQUIX_BATTERY")"
    print_kv 'Thermal reading' "$(metric_or_unavailable "$ORYNQUIX_THERMAL")"
    printf '\n'
    print_kv 'Recommended profile' "$ORYNQUIX_RECOMMENDED_PROFILE"
    print_kv 'Recommended VNC' "$ORYNQUIX_RECOMMENDED_RESOLUTION"
}

validate_supported_device() {
    case "$ORYNQUIX_ARCH" in
        aarch64|x86_64) log_success "Supported architecture: $ORYNQUIX_ARCH" ;;
        *) log_error "Unsupported architecture: $ORYNQUIX_ARCH (ARM64 is required; x86_64 is experimental)."; return 1 ;;
    esac
    if [[ "$ORYNQUIX_STORAGE_FREE_KIB" =~ ^[0-9]+$ ]] && (( ORYNQUIX_STORAGE_FREE_KIB > 0 && ORYNQUIX_STORAGE_FREE_KIB < 8388608 )); then
        log_warn "Less than 8 GiB is free; the selected package set may not fit."
    fi
}
