#!/usr/bin/env bash

install_desktop_launcher() {
    local id=$1 name=$2 comment=$3 executable=$4 icon=$5 home owner content
    home="/home/$ORYNQUIX_USERNAME"
    owner="$ORYNQUIX_USERNAME:$ORYNQUIX_USERNAME"
    content=$(cat <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
Comment=$comment
Exec=$executable
Icon=$icon
Terminal=false
Categories=Orynquix;
StartupNotify=true
EOF
)
    printf '%s\n' "$content" | atomic_install_in_ubuntu "$home/.local/share/applications/$id.desktop" 0644 "$owner"
    printf '%s\n' "$content" | atomic_install_in_ubuntu "$home/Desktop/$id.desktop" 0755 "$owner"
}

write_appearance_user_config() {
    local owner theme scale compositor
    owner="$ORYNQUIX_USERNAME:$ORYNQUIX_USERNAME"
    theme=$(config_get desktop theme)
    scale=$(config_get desktop ui_scale)
    compositor=$(config_get desktop compositor)
    validate_theme_choice "$theme" && validate_ui_scale "$scale" &&
        validate_compositor_choice "$compositor" || return 1
    if [[ "$compositor" == auto ]]; then
        if [[ "$ORYNQUIX_PROFILE" == lite ]]; then compositor=false; else compositor=true; fi
    fi
    cat <<EOF | atomic_install_in_ubuntu "/home/$ORYNQUIX_USERNAME/.config/orynquix/appearance.ini" 0644 "$owner"
theme=$theme
ui_scale=$scale
compositor=$compositor
EOF
}

apply_appearance_live() {
    run_as_ubuntu_user "$ORYNQUIX_USERNAME" /usr/bin/env \
        HOME="/home/$ORYNQUIX_USERNAME" USER="$ORYNQUIX_USERNAME" \
        LOGNAME="$ORYNQUIX_USERNAME" DISPLAY=":$ORYNQUIX_DEFAULT_DISPLAY" \
        /usr/local/libexec/orynquix/apply-appearance
}

configure_orynquix_appearance() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && {
        log_info '[dry-run] Would install Orynquix wallpaper, XFCE appearance, shortcuts, and verified launchers'
        return 0
    }
    atomic_install_in_ubuntu /usr/share/backgrounds/orynquix/orynquix-default.png 0644 root:root \
        <"$ORYNQUIX_PROJECT_ROOT/assets/wallpapers/orynquix-default.png"
    atomic_install_in_ubuntu /usr/local/libexec/orynquix/apply-appearance 0755 root:root \
        <"$ORYNQUIX_PROJECT_ROOT/rootfs/scripts/apply-appearance.sh"
    atomic_install_in_ubuntu /usr/local/libexec/orynquix/start-xfce 0755 root:root \
        <"$ORYNQUIX_PROJECT_ROOT/rootfs/scripts/start-xfce.sh"

    run_in_ubuntu /usr/bin/install -d -m 0755 -o "$ORYNQUIX_USERNAME" -g "$ORYNQUIX_USERNAME" \
        "/home/$ORYNQUIX_USERNAME/Desktop" \
        "/home/$ORYNQUIX_USERNAME/.local/share/applications" \
        "/home/$ORYNQUIX_USERNAME/.config/orynquix"
    write_appearance_user_config

    install_desktop_launcher orynquix-terminal 'Terminal' 'Open the Orynquix terminal' \
        xfce4-terminal utilities-terminal
    install_desktop_launcher orynquix-files 'Files' 'Browse Ubuntu and Android files' \
        thunar system-file-manager
    if run_in_ubuntu /bin/sh -c 'command -v orynquix-firefox >/dev/null 2>&1'; then
        install_desktop_launcher orynquix-firefox 'Firefox' 'Browse the web' \
            orynquix-firefox firefox
        install_desktop_launcher orynquix-youtube 'YouTube' 'Open YouTube in Firefox' \
            'orynquix-firefox --new-window https://www.youtube.com/' firefox
    fi
    if run_in_ubuntu /bin/sh -c 'command -v orynquix-code >/dev/null 2>&1'; then
        install_desktop_launcher orynquix-code 'Visual Studio Code' 'Develop with VS Code' \
            orynquix-code visual-studio-code
    fi
}

verify_orynquix_appearance() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    local home="/home/$ORYNQUIX_USERNAME"
    run_in_ubuntu /usr/bin/test -s /usr/share/backgrounds/orynquix/orynquix-default.png &&
        run_in_ubuntu /usr/bin/test -x /usr/local/libexec/orynquix/apply-appearance &&
        run_in_ubuntu /usr/bin/test -x /usr/local/libexec/orynquix/start-xfce &&
        run_in_ubuntu /usr/bin/test -r "$home/.config/orynquix/appearance.ini" &&
        run_in_ubuntu /usr/bin/test -x "$home/Desktop/orynquix-terminal.desktop" &&
        run_in_ubuntu /usr/bin/test -x "$home/Desktop/orynquix-files.desktop"
}
