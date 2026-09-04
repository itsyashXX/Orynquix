#!/usr/bin/env bash

read_linux_password() {
    local first second
    if [[ -n "$ORYNQUIX_LINUX_PASSWORD_FD" ]]; then
        read -r -u "$ORYNQUIX_LINUX_PASSWORD_FD" first || return 1
        validate_linux_password "$first" || return 1
        ORYNQUIX_LINUX_PASSWORD=$first
        return 0
    fi
    [[ "$ORYNQUIX_NON_INTERACTIVE" != 1 ]] || {
        log_error 'A new user in non-interactive mode requires --linux-password-fd N.'
        return 64
    }
    while true; do
        read -r -s -p "Create password for $ORYNQUIX_USERNAME: " first; printf '\n'
        read -r -s -p 'Confirm Linux password: ' second; printf '\n'
        validate_linux_password "$first" || continue
        [[ "$first" == "$second" ]] || { printf 'Passwords do not match.\n'; continue; }
        ORYNQUIX_LINUX_PASSWORD=$first
        return 0
    done
}

validate_linux_password() {
    local password=${1-}
    (( ${#password} >= 6 )) || { log_error 'The Linux password must contain at least 6 characters.'; return 1; }
    [[ "$password" != *:* ]] || { log_error "The Linux password cannot contain ':'."; return 1; }
    [[ "$password" != *[$'\t\r\n']* ]] || {
        log_error 'The Linux password cannot contain tabs or line breaks.'
        return 1
    }
}

create_linux_user() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && { log_info "[dry-run] Would create standard Ubuntu user '$ORYNQUIX_USERNAME'"; return 0; }
    local password_required=1 sudoers_path="/etc/sudoers.d/90-orynquix-$ORYNQUIX_USERNAME"
    if ubuntu_user_exists; then
        log_success "Existing Linux user '$ORYNQUIX_USERNAME' is healthy; preserving its home"
        password_required=0
    else
        read_linux_password
        run_in_ubuntu /usr/sbin/useradd --create-home --shell /bin/bash "$ORYNQUIX_USERNAME"
    fi

    run_in_ubuntu /usr/sbin/usermod -aG sudo "$ORYNQUIX_USERNAME"
    printf '%s ALL=(ALL:ALL) ALL\n' "$ORYNQUIX_USERNAME" | \
        run_in_ubuntu /usr/bin/tee "$sudoers_path" >/dev/null
    run_in_ubuntu /bin/chmod 0440 "$sudoers_path"
    run_in_ubuntu /usr/sbin/visudo -cf "$sudoers_path" >/dev/null

    if (( password_required )); then
        printf '%s:%s\n' "$ORYNQUIX_USERNAME" "$ORYNQUIX_LINUX_PASSWORD" | run_in_ubuntu /usr/sbin/chpasswd
        unset ORYNQUIX_LINUX_PASSWORD
    fi

    run_as_ubuntu_user "$ORYNQUIX_USERNAME" /usr/bin/env \
        HOME="/home/$ORYNQUIX_USERNAME" LANG=en_US.UTF-8 /usr/bin/xdg-user-dirs-update
    install_ubuntu_markers
}

install_ubuntu_markers() {
    cat <<EOF | run_in_ubuntu /usr/bin/tee /etc/orynquix-release >/dev/null
NAME=Orynquix
VERSION=$ORYNQUIX_VERSION
UBUNTU_VERSION=$ORYNQUIX_ACTUAL_UBUNTU_VERSION
EOF
cat <<'EOF' | run_in_ubuntu /usr/bin/tee /etc/profile.d/orynquix.sh >/dev/null
export ORYNQUIX_INSIDE_PROOT=1
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache/orynquix/runtime}"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
fi
EOF
    run_in_ubuntu /bin/chmod 0644 /etc/orynquix-release /etc/profile.d/orynquix.sh
}

verify_linux_user() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    ubuntu_user_exists &&
        run_in_ubuntu /usr/bin/test -d "/home/$ORYNQUIX_USERNAME" &&
        run_in_ubuntu /usr/bin/stat -c %U "/home/$ORYNQUIX_USERNAME" | grep -qx "$ORYNQUIX_USERNAME" &&
        run_in_ubuntu /usr/sbin/visudo -cf "/etc/sudoers.d/90-orynquix-$ORYNQUIX_USERNAME" >/dev/null &&
        run_in_ubuntu /usr/bin/test -r /etc/orynquix-release &&
        run_in_ubuntu /bin/grep -Fqx "VERSION=$ORYNQUIX_VERSION" /etc/orynquix-release
}
