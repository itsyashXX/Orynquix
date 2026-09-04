#!/usr/bin/env bash
set -Eeuo pipefail

action=${1:-status}
web_port=${2:-6080}
vnc_port=${3:-5901}

valid_port() {
    [[ "${1-}" =~ ^[0-9]{4,5}$ ]] && (( 10#${1} >= 1024 && 10#${1} <= 65535 ))
}
valid_port "$web_port" && valid_port "$vnc_port" && [[ "$web_port" != "$vnc_port" ]] || {
    printf 'Invalid browser-access port configuration.\n' >&2
    exit 64
}

data_dir="$HOME/.local/share/orynquix"
state_dir="$data_dir/state"
log_dir="$data_dir/logs"
metadata="$state_dir/web-session.ini"
session_log="$log_dir/web.log"
mkdir -p "$state_dir" "$log_dir"
chmod 700 "$data_dir" "$state_dir" "$log_dir"
touch "$session_log"
chmod 600 "$session_log"

metadata_pid=''
metadata_ticks=''
metadata_web_port=''
metadata_vnc_port=''

process_start_ticks() { awk '{print $22}' "/proc/$1/stat" 2>/dev/null; }

process_state() {
    local line remainder
    [[ -r "/proc/$1/stat" ]] || return 1
    IFS= read -r line <"/proc/$1/stat" || return 1
    remainder=${line##*) }
    [[ "$remainder" != "$line" ]] || return 1
    printf '%s\n' "${remainder%% *}"
}

pid_is_managed_web() {
    local pid=$1 line web_pattern vnc_pattern
    [[ "$pid" =~ ^[0-9]+$ && -r "/proc/$pid/cmdline" ]] || return 1
    line=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)
    web_pattern="127.0.0.1:${web_port}"
    vnc_pattern="127.0.0.1:${vnc_port}"
    [[ "$line" == *websockify* && "$line" == *"$web_pattern"* && "$line" == *"$vnc_pattern"* ]]
}

same_process_is_live() {
    local pid=$1 ticks=$2 current state
    current=$(process_start_ticks "$pid")
    [[ -n "$current" && "$current" == "$ticks" ]] || return 1
    state=$(process_state "$pid") || return 1
    [[ "$state" != Z && "$state" != X && "$state" != x ]] || return 1
    kill -0 "$pid" 2>/dev/null
}

load_metadata() {
    local key value
    metadata_pid=''; metadata_ticks=''; metadata_web_port=''; metadata_vnc_port=''
    [[ -r "$metadata" ]] || return 1
    while IFS='=' read -r key value; do
        case "$key" in
            pid) [[ "$value" =~ ^[0-9]+$ ]] && metadata_pid=$value ;;
            start_ticks) [[ "$value" =~ ^[0-9]+$ ]] && metadata_ticks=$value ;;
            web_port) valid_port "$value" && metadata_web_port=$value ;;
            vnc_port) valid_port "$value" && metadata_vnc_port=$value ;;
        esac
    done <"$metadata"
    [[ -n "$metadata_pid" && -n "$metadata_ticks" && "$metadata_web_port" == "$web_port" &&
        "$metadata_vnc_port" == "$vnc_port" ]]
}

metadata_is_live() {
    load_metadata && pid_is_managed_web "$metadata_pid" && same_process_is_live "$metadata_pid" "$metadata_ticks"
}

port_is_listening() {
    (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

remove_metadata() { [[ ! -e "$metadata" ]] || rm -f -- "$metadata"; }

write_metadata() {
    local pid=$1 temporary ticks
    ticks=$(process_start_ticks "$pid")
    [[ "$ticks" =~ ^[0-9]+$ ]] || return 1
    temporary=$(mktemp "$state_dir/.web-session.XXXXXX")
    chmod 600 "$temporary"
    {
        printf 'pid=%s\n' "$pid"
        printf 'start_ticks=%s\n' "$ticks"
        printf 'web_port=%s\n' "$web_port"
        printf 'vnc_port=%s\n' "$vnc_port"
        printf 'localhost=true\n'
        printf 'started_at=%s\n' "$(date -u +%FT%TZ)"
    } >"$temporary"
    mv -f -- "$temporary" "$metadata"
}

terminate_managed_web() {
    local pid=$1 ticks=$2 attempt
    pid_is_managed_web "$pid" && same_process_is_live "$pid" "$ticks" || return 1
    kill -TERM "$pid" 2>/dev/null || true
    for attempt in {1..16}; do
        same_process_is_live "$pid" "$ticks" || return 0
        sleep 0.25
    done
    pid_is_managed_web "$pid" && same_process_is_live "$pid" "$ticks" || return 0
    kill -KILL "$pid" 2>/dev/null || true
    for attempt in {1..4}; do
        same_process_is_live "$pid" "$ticks" || return 0
        sleep 0.25
    done
    return 1
}

print_running() {
    printf 'state=running\n'
    printf 'pid=%s\n' "$1"
    printf 'web_port=%s\n' "$web_port"
    printf 'vnc_port=%s\n' "$vnc_port"
    printf 'localhost=true\n'
}

start_session() {
    local pid='' attempt webroot=/usr/share/novnc
    if metadata_is_live; then
        if port_is_listening "$web_port"; then print_running "$metadata_pid"; return 0; fi
        terminate_managed_web "$metadata_pid" "$metadata_ticks" || {
            printf 'Managed browser proxy is unhealthy and could not be stopped safely.\n' >&2
            return 1
        }
        remove_metadata
    elif [[ -e "$metadata" ]]; then
        remove_metadata
    fi

    if port_is_listening "$web_port"; then
        printf 'Port %s is already in use; refusing to take ownership.\n' "$web_port" >&2
        return 4
    fi
    command -v websockify >/dev/null 2>&1 || { printf 'websockify is unavailable.\n' >&2; return 127; }
    [[ -r "$webroot/vnc.html" ]] || { printf 'noVNC web files are unavailable.\n' >&2; return 1; }

    setsid websockify --web "$webroot" "127.0.0.1:$web_port" "127.0.0.1:$vnc_port" \
        >>"$session_log" 2>&1 </dev/null &
    pid=$!
    for attempt in {1..30}; do
        if pid_is_managed_web "$pid" && port_is_listening "$web_port"; then
            write_metadata "$pid"
            print_running "$pid"
            return 0
        fi
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
    done
    if pid_is_managed_web "$pid"; then
        local ticks
        ticks=$(process_start_ticks "$pid")
        [[ "$ticks" =~ ^[0-9]+$ ]] && terminate_managed_web "$pid" "$ticks" || true
    fi
    printf 'Browser proxy did not become healthy. Log: %s\n' "$session_log" >&2
    return 1
}

stop_session() {
    if metadata_is_live; then
        terminate_managed_web "$metadata_pid" "$metadata_ticks" || return 1
    fi
    remove_metadata
    printf 'state=stopped\n'
}

status_session() {
    if metadata_is_live && port_is_listening "$web_port"; then
        print_running "$metadata_pid"
        return 0
    fi
    if [[ -e "$metadata" ]]; then
        printf 'state=stale\n'
        return 3
    fi
    printf 'state=stopped\n'
    return 3
}

case "$action" in
    start) start_session ;;
    stop) stop_session ;;
    status) status_session ;;
    log) tail -n 200 "$session_log" ;;
    *) printf 'Unknown browser session action: %s\n' "$action" >&2; exit 64 ;;
esac
