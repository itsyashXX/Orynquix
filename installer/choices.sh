#!/usr/bin/env bash

apply_profile_defaults() {
    case "$ORYNQUIX_PROFILE" in
        lite)
            ORYNQUIX_BROWSER=${ORYNQUIX_BROWSER:-none}
            ORYNQUIX_EDITOR=${ORYNQUIX_EDITOR:-none}
            ORYNQUIX_DEV_TOOLS=${ORYNQUIX_DEV_TOOLS:-none}
            ;;
        standard)
            ORYNQUIX_BROWSER=${ORYNQUIX_BROWSER:-chromium}
            ORYNQUIX_EDITOR=${ORYNQUIX_EDITOR:-auto}
            ORYNQUIX_DEV_TOOLS=${ORYNQUIX_DEV_TOOLS:-recommended}
            ;;
        developer)
            ORYNQUIX_BROWSER=${ORYNQUIX_BROWSER:-chromium}
            ORYNQUIX_EDITOR=${ORYNQUIX_EDITOR:-auto}
            ORYNQUIX_DEV_TOOLS=${ORYNQUIX_DEV_TOOLS:-full}
            ;;
        complete)
            ORYNQUIX_BROWSER=${ORYNQUIX_BROWSER:-both}
            ORYNQUIX_EDITOR=${ORYNQUIX_EDITOR:-both}
            ORYNQUIX_DEV_TOOLS=${ORYNQUIX_DEV_TOOLS:-full}
            ;;
        custom) ;;
    esac
    ORYNQUIX_RESOLUTION=${ORYNQUIX_RESOLUTION:-$ORYNQUIX_RECOMMENDED_RESOLUTION}
}

load_saved_choices() {
    [[ -r "$ORYNQUIX_CONFIG_FILE" ]] || return 1
    local profile username browser editor dev_tools resolution audio storage compositor ui_scale
    profile=$(config_get system profile || true)
    username=$(config_get user name || true)
    browser=$(config_get applications browser || true)
    editor=$(config_get applications editor || true)
    dev_tools=$(config_get applications development_tools || true)
    resolution=$(config_get vnc resolution || true)
    audio=$(config_get audio enabled || true)
    storage=$(config_get android storage || true)
    compositor=$(config_get desktop compositor || true)
    ui_scale=$(config_get desktop ui_scale || true)

    validate_profile "$profile" && validate_username "$username" &&
        validate_browser_choice "$browser" && validate_editor_choice "$editor" &&
        validate_dev_tools_choice "$dev_tools" && validate_resolution "$resolution" &&
        validate_tristate "${audio:-auto}" && validate_tristate "${storage:-auto}" &&
        validate_compositor_choice "${compositor:-auto}" && validate_ui_scale "${ui_scale:-1.0}" || return 1

    ORYNQUIX_PROFILE=$profile
    ORYNQUIX_USERNAME=$username
    ORYNQUIX_BROWSER=$browser
    ORYNQUIX_EDITOR=$editor
    ORYNQUIX_DEV_TOOLS=$dev_tools
    ORYNQUIX_RESOLUTION=$resolution
    ORYNQUIX_AUDIO=${audio:-auto}
    ORYNQUIX_STORAGE=${storage:-auto}
    ORYNQUIX_COMPOSITOR=${compositor:-auto}
    ORYNQUIX_UI_SCALE=${ui_scale:-1.0}
}

choose_profile_interactive() {
    local choice
    prompt_menu choice 'Choose an installation preset:' 1 \
        '1. Recommended — adapt to this device' \
        '2. Complete — install every component offered by this installer' \
        '3. Minimal — Ubuntu + XFCE essentials only' \
        '4. Developer — desktop plus the full development bundle' \
        '5. Custom — choose every optional category'
    case "$choice" in
        1) ORYNQUIX_PROFILE=$ORYNQUIX_RECOMMENDED_PROFILE ;;
        2) ORYNQUIX_PROFILE=complete ;;
        3) ORYNQUIX_PROFILE=lite ;;
        4) ORYNQUIX_PROFILE=developer ;;
        5) ORYNQUIX_PROFILE=custom ;;
    esac
}

choose_browser_interactive() {
    local choice
    prompt_menu choice 'Which browser should Orynquix install?' 1 \
        '1. Chromium' \
        '2. Firefox' \
        '3. Both Chromium and Firefox' \
        '4. Skip browsers'
    case "$choice" in
        1) ORYNQUIX_BROWSER=chromium ;;
        2) ORYNQUIX_BROWSER=firefox ;;
        3) ORYNQUIX_BROWSER=both ;;
        4) ORYNQUIX_BROWSER=none ;;
    esac
}

choose_editor_interactive() {
    local choice
    prompt_menu choice 'Which coding editor should Orynquix configure?' 1 \
        '1. Automatic — compatible VS Code build, then code-server fallback' \
        '2. VS Code desktop only' \
        '3. code-server only' \
        '4. Both VS Code desktop and code-server' \
        '5. Skip coding editors'
    case "$choice" in
        1) ORYNQUIX_EDITOR=auto ;;
        2) ORYNQUIX_EDITOR=vscode ;;
        3) ORYNQUIX_EDITOR=code-server ;;
        4) ORYNQUIX_EDITOR=both ;;
        5) ORYNQUIX_EDITOR=none ;;
    esac
}

validate_custom_dev_list() {
    local csv=$1 item
    local -a items=()
    [[ -n "$csv" ]] || return 1
    IFS=',' read -r -a items <<<"$csv"
    for item in "${items[@]}"; do
        [[ ",$ORYNQUIX_DEV_TOOL_IDS," == *",$item,"* ]] || return 1
    done
}

choose_custom_dev_tools() {
    local selected
    cat <<'EOF'

Available development groups:
  git, github-cli, python, node, java, cpp, cmake, clang,
  jupyter, databases, neovim
EOF
    while true; do
        read -r -p 'Enter comma-separated group names: ' selected
        selected=${selected// /}
        if validate_custom_dev_list "$selected"; then
            ORYNQUIX_DEV_TOOLS="custom:$selected"
            return 0
        fi
        printf 'Use only the listed names, separated by commas.\n'
    done
}

choose_dev_tools_interactive() {
    if ! prompt_yes_no 'Do you want coding and development tools?' yes; then
        ORYNQUIX_DEV_TOOLS=none
        return 0
    fi
    local choice
    prompt_menu choice 'Choose the development tool set:' 1 \
        '1. Recommended — Git, Python, Node.js, compiler basics and utilities' \
        '2. Full — all supported languages, toolchains and database clients' \
        '3. Custom — choose individual groups' \
        '4. Skip development tools'
    case "$choice" in
        1) ORYNQUIX_DEV_TOOLS=recommended ;;
        2) ORYNQUIX_DEV_TOOLS=full ;;
        3) choose_custom_dev_tools ;;
        4) ORYNQUIX_DEV_TOOLS=none ;;
    esac
}

choose_username_interactive() {
    local username
    while true; do
        read -r -p "Linux username [$ORYNQUIX_USERNAME]: " username
        username=${username:-$ORYNQUIX_USERNAME}
        if validate_username "$username"; then
            ORYNQUIX_USERNAME=$username
            return 0
        fi
        printf 'Use 1–32 lowercase letters, digits, underscores or hyphens; do not use root/system names.\n'
    done
}

configure_installation_choices() {
    local explicit_choices=0
    [[ -n "$ORYNQUIX_PROFILE$ORYNQUIX_BROWSER$ORYNQUIX_EDITOR$ORYNQUIX_DEV_TOOLS" ]] && explicit_choices=1

    if [[ "$ORYNQUIX_RECONFIGURE" != 1 && "$explicit_choices" == 0 ]] && load_saved_choices; then
        log_success "Loaded previously validated installation choices"
        show_installation_plan
        [[ "$ORYNQUIX_DRY_RUN" == 1 ]] || write_runtime_config
        return 0
    fi

    if [[ "$ORYNQUIX_NON_INTERACTIVE" == 1 ]]; then
        ORYNQUIX_PROFILE=${ORYNQUIX_PROFILE:-$ORYNQUIX_RECOMMENDED_PROFILE}
        [[ "$ORYNQUIX_PROFILE" != custom ]] || {
            [[ -n "$ORYNQUIX_BROWSER" && -n "$ORYNQUIX_EDITOR" && -n "$ORYNQUIX_DEV_TOOLS" ]] || {
                log_error 'Custom non-interactive installs require --browser, --editor, and --dev-tools.'
                return 64
            }
        }
    else
        [[ -n "$ORYNQUIX_PROFILE" ]] || choose_profile_interactive
    fi

    apply_profile_defaults

    if [[ "$ORYNQUIX_PROFILE" == custom ]]; then
        [[ -n "$ORYNQUIX_BROWSER" ]] || choose_browser_interactive
        [[ -n "$ORYNQUIX_EDITOR" ]] || choose_editor_interactive
        [[ -n "$ORYNQUIX_DEV_TOOLS" ]] || choose_dev_tools_interactive
    fi

    if [[ "$ORYNQUIX_NON_INTERACTIVE" != 1 ]]; then
        choose_username_interactive
    fi
    verify_choices
    show_installation_plan

    if [[ "$ORYNQUIX_DRY_RUN" != 1 && "$ORYNQUIX_ASSUME_YES" != 1 ]]; then
        [[ "$ORYNQUIX_NON_INTERACTIVE" != 1 ]] || {
            log_error 'A non-interactive installation requires --yes before making changes.'
            return 64
        }
        prompt_yes_no 'Continue with this installation plan?' yes || {
            log_warn 'Installation cancelled before any Ubuntu changes.'
            exit 0
        }
    fi

    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] || write_runtime_config
}

show_installation_plan() {
    printf '\n%sINSTALLATION PLAN%s\n\n' "$C_BOLD" "$C_RESET"
    print_kv Profile "$ORYNQUIX_PROFILE"
    print_kv 'Linux user' "$ORYNQUIX_USERNAME"
    print_kv Browser "$ORYNQUIX_BROWSER"
    print_kv Editor "$ORYNQUIX_EDITOR"
    print_kv 'Development tools' "$ORYNQUIX_DEV_TOOLS"
    print_kv Resolution "$ORYNQUIX_RESOLUTION"
    print_kv Audio "$ORYNQUIX_AUDIO"
    print_kv 'Android storage' "$ORYNQUIX_STORAGE"
    printf '\nPackage download details will be hidden; verified stage progress remains visible.\n'
    printf 'Detailed log: %s\n' "$ORYNQUIX_INSTALL_LOG"
}

verify_choices() {
    validate_profile "$ORYNQUIX_PROFILE" &&
        validate_username "$ORYNQUIX_USERNAME" &&
        validate_browser_choice "$ORYNQUIX_BROWSER" &&
        validate_editor_choice "$ORYNQUIX_EDITOR" &&
        validate_dev_tools_choice "$ORYNQUIX_DEV_TOOLS" &&
        validate_resolution "$ORYNQUIX_RESOLUTION" &&
        validate_ui_scale "$ORYNQUIX_UI_SCALE" &&
        validate_tristate "$ORYNQUIX_AUDIO" &&
        validate_tristate "$ORYNQUIX_STORAGE" &&
        validate_compositor_choice "$ORYNQUIX_COMPOSITOR"
}

write_runtime_config() {
    local actual_release=${ORYNQUIX_ACTUAL_UBUNTU_VERSION:-}
    if [[ -z "$actual_release" && -r "$ORYNQUIX_STATE_DIR/ubuntu-release" ]]; then
        read -r actual_release <"$ORYNQUIX_STATE_DIR/ubuntu-release" || true
    fi
    actual_release=${actual_release:-pending}
    cat <<EOF | atomic_write "$ORYNQUIX_CONFIG_FILE" 600
[system]
version=$ORYNQUIX_SCHEMA_VERSION
product_version=$ORYNQUIX_VERSION
profile=$ORYNQUIX_PROFILE

[ubuntu]
distribution=ubuntu
preferred_release=$ORYNQUIX_PREFERRED_UBUNTU
actual_release=$actual_release

[user]
name=$ORYNQUIX_USERNAME

[desktop]
environment=xfce
theme=orynquix-dark
wallpaper=orynquix-default
ui_scale=$ORYNQUIX_UI_SCALE
compositor=$ORYNQUIX_COMPOSITOR

[vnc]
display=$ORYNQUIX_DEFAULT_DISPLAY
port=$((5900 + ORYNQUIX_DEFAULT_DISPLAY))
resolution=$ORYNQUIX_RESOLUTION
depth=$ORYNQUIX_DEFAULT_DEPTH
localhost=true

[applications]
browser=$ORYNQUIX_BROWSER
editor=$ORYNQUIX_EDITOR
development_tools=$ORYNQUIX_DEV_TOOLS

[audio]
enabled=$ORYNQUIX_AUDIO

[android]
storage=$ORYNQUIX_STORAGE
EOF
    verify_choices
}
