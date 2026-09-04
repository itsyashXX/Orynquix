#!/usr/bin/env bash
set -Eeuo pipefail

action=${1:-status}
display=${2:-1}
geometry=${3:-1280x720}
depth=${4:-24}

[[ "$display" =~ ^[0-9]{1,2}$ ]] && (( 10#$display >= 1 && 10#$display <= 99 )) || {
    printf 'Invalid VNC display.\n' >&2
    exit 64
}
port=$((5900 + 10#$display))
[[ "$geometry" =~ ^[0-9]{3,5}x[0-9]{3,5}$ ]] || {
    printf 'Invalid VNC geometry.\n' >&2
    exit 64
}
[[ "$depth" == 16 || "$depth" == 24 || "$depth" == 32 ]] || {
    printf 'Invalid VNC depth.\n' >&2
    exit 64
}

data_dir="$HOME/.local/share/orynquix"
state_dir="$data_dir/state"
log_dir="$data_dir/logs"
vnc_dir="$data_dir/vnc"
metadata="$state_dir/vnc-session.ini"
session_log="$log_dir/vnc.log"
xstartup="$vnc_dir/xstartup"
password_file="$HOME/.config/tigervnc/passwd"

mkdir -p "$state_dir" "$log_dir" "$vnc_dir"
chmod 700 "$data_dir" "$state_dir" "$log_dir" "$vnc_dir"
touch "$session_log"
chmod 600 "$session_log"

metadata_pid=''
metadata_display=''
metadata_start_ticks=''
metadata_port=''
metadata_resolution=''
metadata_depth=''

load_metadata() {
    local key value
    metadata_pid=''
    metadata_display=''
    metadata_start_ticks=''
    metadata_port=''
    metadata_resolution=''
    metadata_depth=''
    [[ -r "$metadata" ]] || return 1
    while IFS='=' read -r key value; do
        case "$key" in
            pid) [[ "$value" =~ ^[0-9]+$ ]] && metadata_pid=$value ;;
            display) [[ "$value" =~ ^:[0-9]{1,2}$ ]] && metadata_display=$value ;;
            start_ticks) [[ "$value" =~ ^[0-9]+$ ]] && metadata_start_ticks=$value ;;
            port) [[ "$value" =~ ^[0-9]{4,5}$ ]] && metadata_port=$value ;;
            resolution) [[ "$value" =~ ^[0-9]{3,5}x[0-9]{3,5}$ ]] && metadata_resolution=$value ;;
            depth) [[ "$value" == 16 || "$value" == 24 || "$value" == 32 ]] && metadata_depth=$value ;;
        esac
    done <"$metadata"
    [[ -n "$metadata_pid" && -n "$metadata_start_ticks" && -n "$metadata_port" &&
        -n "$metadata_resolution" && -n "$metadata_depth" && "$metadata_display" == ":$display" ]]
}

pid_is_orynquix_vnc() {
    local pid=${1-} command_line pattern
    [[ "$pid" =~ ^[0-9]+$ && -r "/proc/$pid/cmdline" ]] || return 1
    command_line=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
    pattern="(^|[[:space:]]):${display}([[:space:]]|$)"
    [[ "$command_line" == *Xtigervnc* && "$command_line" =~ $pattern ]]
}

process_start_ticks() {
    local pid=$1
    awk '{print $22}' "/proc/$pid/stat" 2>/dev/null
}

process_state() {
    local pid=$1 stat_line remainder
    [[ -r "/proc/$pid/stat" ]] || return 1
    IFS= read -r stat_line <"/proc/$pid/stat" || return 1
    remainder=${stat_line##*) }
    [[ "$remainder" != "$stat_line" ]] || return 1
    printf '%s\n' "${remainder%% *}"
}

pid_is_live() {
    local pid=$1 state
    state=$(process_state "$pid") || return 1
    [[ "$state" != Z && "$state" != X && "$state" != x ]] || return 1
    kill -0 "$pid" 2>/dev/null
}

same_process_is_live() {
    local pid=$1 expected_ticks=$2 current_ticks
    current_ticks=$(process_start_ticks "$pid")
    [[ -n "$current_ticks" && "$current_ticks" == "$expected_ticks" ]] || return 1
    pid_is_live "$pid"
}

pid_matches_metadata() {
    local pid=$1 current_ticks
    pid_is_orynquix_vnc "$pid" || return 1
    current_ticks=$(process_start_ticks "$pid")
    [[ -n "$current_ticks" && "$current_ticks" == "$metadata_start_ticks" ]]
}

discover_display_pid() {
    local candidate pid
    for candidate in "$HOME/.config/tigervnc/"*":${display}.pid" "$HOME/.vnc/"*":${display}.pid"; do
        [[ -r "$candidate" ]] || continue
        read -r pid <"$candidate" || continue
        if pid_is_orynquix_vnc "$pid"; then
            printf '%s\n' "$pid"
            return 0
        fi
    done
    if command -v pgrep >/dev/null 2>&1; then
        while read -r pid; do
            pid_is_orynquix_vnc "$pid" || continue
            printf '%s\n' "$pid"
            return 0
        done < <(pgrep -u "$(id -u)" -f "Xtigervnc.*:${display}([[:space:]]|$)" 2>/dev/null || true)
    fi
    return 1
}

port_is_listening() {
    (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
}

remove_metadata() {
    [[ -e "$metadata" ]] && rm -f -- "$metadata"
}

remove_matching_pid_files() {
    local expected_pid=$1 candidate candidate_pid
    for candidate in "$HOME/.config/tigervnc/"*":${display}.pid" "$HOME/.vnc/"*":${display}.pid"; do
        [[ -f "$candidate" ]] || continue
        read -r candidate_pid <"$candidate" || candidate_pid=''
        [[ "$candidate_pid" == "$expected_pid" ]] && rm -f -- "$candidate"
    done
}

cleanup_stale_display_files() {
    local lock_file="/tmp/.X${display}-lock" socket_file="/tmp/.X11-unix/X${display}" lock_pid='' stale_lock=false
    if [[ -r "$lock_file" ]]; then
        read -r lock_pid <"$lock_file" || lock_pid=''
        lock_pid=${lock_pid//[[:space:]]/}
        if [[ "$lock_pid" =~ ^[0-9]+$ ]] && pid_is_live "$lock_pid"; then
            printf 'Display :%s is owned by active PID %s; refusing cleanup.\n' "$display" "$lock_pid" >&2
            return 1
        fi
        rm -f -- "$lock_file"
        stale_lock=true
    fi
    if [[ -S "$socket_file" || -e "$socket_file" ]]; then
        if command -v xdpyinfo >/dev/null 2>&1 && DISPLAY=":$display" xdpyinfo >/dev/null 2>&1; then
            printf 'Display :%s responds to X11; refusing socket cleanup.\n' "$display" >&2
            return 1
        fi
        if [[ "$stale_lock" == true ]] || command -v xdpyinfo >/dev/null 2>&1; then
            rm -f -- "$socket_file"
        else
            printf 'Cannot prove that X11 socket %s is stale; refusing cleanup.\n' "$socket_file" >&2
            return 1
        fi
    fi
}

write_metadata() {
    local pid=$1 temporary start_ticks
    start_ticks=$(process_start_ticks "$pid")
    [[ "$start_ticks" =~ ^[0-9]+$ ]] || {
        printf 'Unable to record the VNC process identity.\n' >&2
        return 1
    }
    temporary=$(mktemp "$state_dir/.vnc-session.XXXXXX")
    chmod 600 "$temporary"
    {
        printf 'pid=%s\n' "$pid"
        printf 'start_ticks=%s\n' "$start_ticks"
        printf 'display=:%s\n' "$display"
        printf 'port=%s\n' "$port"
        printf 'resolution=%s\n' "$geometry"
        printf 'depth=%s\n' "$depth"
        printf 'localhost=true\n'
        printf 'started_at=%s\n' "$(date -u +%FT%TZ)"
    } >"$temporary"
    mv -f -- "$temporary" "$metadata"
}

print_running() {
    local pid=$1 active_geometry=${2:-$geometry}
    printf 'state=running\n'
    printf 'pid=%s\n' "$pid"
    printf 'display=:%s\n' "$display"
    printf 'port=%s\n' "$port"
    printf 'resolution=%s\n' "$active_geometry"
    printf 'localhost=true\n'
}

terminate_exact_vnc_pid() {
    local pid=$1 attempt original_ticks
    pid_is_orynquix_vnc "$pid" || return 1
    original_ticks=$(process_start_ticks "$pid")
    [[ "$original_ticks" =~ ^[0-9]+$ ]] || return 1
    kill -TERM "$pid" 2>/dev/null || true
    for attempt in {1..16}; do
        same_process_is_live "$pid" "$original_ticks" || return 0
        sleep 0.5
    done
    pid_is_orynquix_vnc "$pid" && same_process_is_live "$pid" "$original_ticks" || return 0
    kill -KILL "$pid" 2>/dev/null || true
    for attempt in {1..6}; do
        same_process_is_live "$pid" "$original_ticks" || return 0
        sleep 0.5
    done
    return 1
}

start_session() {
    local pid='' server='' attempt
    if load_metadata && pid_matches_metadata "$metadata_pid"; then
        if port_is_listening; then
            print_running "$metadata_pid" "$metadata_resolution"
            return 0
        fi
        printf 'Recovering unhealthy managed VNC PID %s.\n' "$metadata_pid" >>"$session_log"
        terminate_exact_vnc_pid "$metadata_pid" || {
            printf 'Managed VNC PID %s is active but its port is unhealthy; automatic restart was refused.\n' "$metadata_pid" >&2
            return 1
        }
        remove_matching_pid_files "$metadata_pid"
        remove_metadata
    fi
    if pid=$(discover_display_pid); then
        printf 'Display :%s already has an unregistered TigerVNC process (PID %s). Refusing to take ownership.\n' "$display" "$pid" >&2
        return 4
    fi
    remove_metadata
    cleanup_stale_display_files

    [[ -x "$xstartup" ]] || { printf 'Missing executable xstartup: %s\n' "$xstartup" >&2; return 1; }
    [[ -s "$password_file" ]] || { printf 'VNC password is not configured.\n' >&2; return 1; }
    if command -v tigervncserver >/dev/null 2>&1; then
        server=$(command -v tigervncserver)
    elif command -v vncserver >/dev/null 2>&1; then
        server=$(command -v vncserver)
    else
        printf 'TigerVNC server executable is unavailable.\n' >&2
        return 127
    fi

    {
        printf '\n[%s] Starting display :%s at %s\n' "$(date -u +%FT%TZ)" "$display" "$geometry"
        "$server" ":$display" -geometry "$geometry" -depth "$depth" \
            -rfbport "$port" -localhost yes -SecurityTypes VncAuth -PasswordFile "$password_file" \
            -AlwaysShared \
            -xstartup "$xstartup"
    } >>"$session_log" 2>&1 || {
        printf 'TigerVNC failed to start. Log: %s\n' "$session_log" >&2
        return 1
    }

    for attempt in {1..30}; do
        pid=$(discover_display_pid || true)
        if [[ -n "$pid" ]] && pid_is_orynquix_vnc "$pid" && port_is_listening; then
            if write_metadata "$pid"; then
                print_running "$pid" "$geometry"
                return 0
            fi
            terminate_exact_vnc_pid "$pid" || true
            remove_matching_pid_files "$pid"
            return 1
        fi
        sleep 0.5
    done

    if [[ -n "$pid" ]] && pid_is_orynquix_vnc "$pid"; then
        terminate_exact_vnc_pid "$pid" || true
        remove_matching_pid_files "$pid"
    fi
    cleanup_stale_display_files || true
    printf 'TigerVNC did not become healthy on 127.0.0.1:%s. Log: %s\n' "$port" "$session_log" >&2
    return 1
}

stop_session() {
    local pid
    if ! load_metadata; then
        if [[ -e "$metadata" ]]; then
            remove_metadata
            cleanup_stale_display_files || true
            printf 'recovered_stale_metadata=true\n'
        fi
        printf 'state=stopped\n'
        return 0
    fi
    pid=$metadata_pid
    if ! pid_matches_metadata "$pid"; then
        remove_metadata
        cleanup_stale_display_files || true
        printf 'state=stopped\n'
        printf 'recovered_stale_metadata=true\n'
        return 0
    fi

    terminate_exact_vnc_pid "$pid" || { printf 'Unable to stop managed VNC PID %s.\n' "$pid" >&2; return 1; }

    remove_matching_pid_files "$pid"
    remove_metadata
    cleanup_stale_display_files
    printf 'state=stopped\n'
}

status_session() {
    if load_metadata && pid_matches_metadata "$metadata_pid" && port_is_listening; then
        print_running "$metadata_pid" "$metadata_resolution"
        return 0
    fi
    if load_metadata && pid_matches_metadata "$metadata_pid"; then
        printf 'state=unhealthy\n'
        printf 'pid=%s\n' "$metadata_pid"
        printf 'display=:%s\n' "$display"
        printf 'port=%s\n' "$metadata_port"
        printf 'resolution=%s\n' "$metadata_resolution"
        return 3
    fi
    if load_metadata && ! pid_matches_metadata "$metadata_pid"; then
        printf 'state=stale\n'
        printf 'pid=%s\n' "$metadata_pid"
        return 3
    fi
    if [[ -e "$metadata" ]]; then
        printf 'state=stale\n'
        printf 'reason=invalid_metadata\n'
        return 3
    fi
    printf 'state=stopped\n'
    return 3
}

case "$action" in
    start) start_session ;;
    stop) stop_session ;;
    status|sessions) status_session ;;
    log) tail -n 200 "$session_log" ;;
    *) printf 'Unknown VNC session action: %s\n' "$action" >&2; exit 64 ;;
esac
