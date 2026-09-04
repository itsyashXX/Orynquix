#!/usr/bin/env bash

append_unique_package() {
    local package=$1 existing
    for existing in "${ORYNQUIX_SELECTED_PACKAGES[@]:-}"; do
        [[ "$existing" == "$package" ]] && return 0
    done
    ORYNQUIX_SELECTED_PACKAGES+=("$package")
}

append_package_group() {
    local package
    for package in "$@"; do append_unique_package "$package"; done
}

collect_development_packages() {
    local selection=$ORYNQUIX_DEV_TOOLS csv group
    local -a groups=()
    ORYNQUIX_SELECTED_PACKAGES=()
    [[ "$selection" != none ]] || return 0
    if [[ "$selection" == recommended ]]; then
        csv='git,python,node,cpp,cmake,clang'
    elif [[ "$selection" == full ]]; then
        csv="$ORYNQUIX_DEV_TOOL_IDS"
    else
        csv=${selection#custom:}
    fi
    IFS=',' read -r -a groups <<<"$csv"
    for group in "${groups[@]}"; do
        case "$group" in
            git) append_package_group git curl wget openssh-client rsync ;;
            github-cli) append_package_group gh ;;
            python) append_package_group python3 python3-pip python3-venv python3-dev ;;
            node) append_package_group nodejs npm ;;
            java) append_package_group default-jdk ;;
            cpp) append_package_group build-essential g++ make pkg-config ;;
            cmake) append_package_group cmake ;;
            clang) append_package_group clang ;;
            jupyter) append_package_group jupyter-notebook ;;
            databases) append_package_group sqlite3 postgresql-client mariadb-client redis-tools ;;
            neovim) append_package_group neovim ;;
        esac
    done
    append_package_group jq ripgrep fd-find tree zip unzip htop nano vim
}

install_development_tools() {
    collect_development_packages
    (( ${#ORYNQUIX_SELECTED_PACKAGES[@]} )) || {
        log_success 'Development tools were skipped by user choice'
        return 0
    }
    verify_packages_available "${ORYNQUIX_SELECTED_PACKAGES[@]}"
    run_visible_or_logged 'Installing selected development tools' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y -q \
            "${ORYNQUIX_SELECTED_PACKAGES[@]}"
}

install_firefox_repository() {
    run_visible_or_logged 'Installing Firefox from the signed Mozilla repository' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /bin/sh -c '
            set -eu
            expected=35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
            key_tmp=$(mktemp /tmp/orynquix-mozilla-key.XXXXXX)
            list_tmp=$(mktemp /tmp/orynquix-mozilla-list.XXXXXX)
            pin_tmp=$(mktemp /tmp/orynquix-mozilla-pin.XXXXXX)
            trap '\''rm -f "$key_tmp" "$list_tmp" "$pin_tmp"'\'' EXIT HUP INT TERM
            apt-get install -y -q ca-certificates curl gnupg
            curl -fsSL --proto "=https" --proto-redir "=https" \
                https://packages.mozilla.org/apt/repo-signing-key.gpg -o "$key_tmp"
            actual=$(gpg --batch --show-keys --with-colons "$key_tmp" | awk -F: '\''$1=="fpr" {print $10; exit}'\'')
            test "$actual" = "$expected"
            install -d -m 0755 /etc/apt/keyrings
            install -m 0644 "$key_tmp" /etc/apt/keyrings/packages.mozilla.org.asc
            printf "%s\n" "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" >"$list_tmp"
            printf "%s\n" "Package: *" "Pin: origin packages.mozilla.org" "Pin-Priority: 1000" \
                >"$pin_tmp"
            install -m 0644 "$list_tmp" /etc/apt/sources.list.d/mozilla.list
            install -m 0644 "$pin_tmp" /etc/apt/preferences.d/mozilla
            apt-get update -q
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q firefox
        '
    cat <<'EOF' | atomic_install_in_ubuntu /usr/local/bin/orynquix-firefox 0755 root:root
#!/bin/sh
# Firefox's Linux namespace sandbox is unavailable in standard Android PRoot.
export MOZ_DISABLE_CONTENT_SANDBOX=1
exec /usr/bin/firefox "$@"
EOF
}

install_vscode_repository() {
    run_visible_or_logged 'Installing VS Code from the signed Microsoft repository' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /bin/sh -c '
            set -eu
            expected=BC528686B50D79E339D3721CEB3E94ADBE1229CF
            key_tmp=$(mktemp /tmp/orynquix-microsoft-key.XXXXXX)
            keyring_tmp=$(mktemp /tmp/orynquix-microsoft-keyring.XXXXXX)
            source_tmp=$(mktemp /tmp/orynquix-vscode-source.XXXXXX)
            trap '\''rm -f "$key_tmp" "$keyring_tmp" "$source_tmp"'\'' EXIT HUP INT TERM
            apt-get install -y -q ca-certificates curl gnupg
            curl -fsSL --proto "=https" --proto-redir "=https" \
                https://packages.microsoft.com/keys/microsoft.asc -o "$key_tmp"
            actual=$(gpg --batch --show-keys --with-colons "$key_tmp" | awk -F: '\''$1=="fpr" {print $10; exit}'\'')
            test "$actual" = "$expected"
            gpg --batch --dearmor <"$key_tmp" >"$keyring_tmp"
            install -m 0644 "$keyring_tmp" /usr/share/keyrings/microsoft.gpg
            printf "%s\n" \
                "Types: deb" \
                "URIs: https://packages.microsoft.com/repos/code" \
                "Suites: stable" \
                "Components: main" \
                "Architectures: amd64 arm64 armhf" \
                "Signed-By: /usr/share/keyrings/microsoft.gpg" \
                >"$source_tmp"
            install -m 0644 "$source_tmp" /etc/apt/sources.list.d/vscode.sources
            apt-get update -q
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q code
        '
    cat <<'EOF' | atomic_install_in_ubuntu /usr/local/bin/orynquix-code 0755 root:root
#!/bin/sh
# Electron cannot create its normal Chromium sandbox inside standard PRoot.
exec /usr/bin/code --no-sandbox --disable-dev-shm-usage "$@"
EOF
}

install_code_server_release() {
    run_visible_or_logged 'Installing the official code-server release' "$ORYNQUIX_INSTALL_LOG" \
        run_in_ubuntu /bin/bash -c '
            set -Eeuo pipefail
            temporary=$(mktemp -d /tmp/orynquix-code-server.XXXXXX)
            trap '\''rm -rf -- "$temporary"'\'' EXIT HUP INT TERM
            release_json="$temporary/release.json"
            apt-get install -y -q ca-certificates curl jq
            curl -fsSL --proto "=https" --proto-redir "=https" \
                https://api.github.com/repos/coder/code-server/releases/latest -o "$release_json"
            version=$(jq -r '\''.tag_name // empty'\'' "$release_json")
            version=${version#v}
            [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
            test -n "$version"
            architecture=$(dpkg --print-architecture)
            case "$architecture" in arm64|amd64) ;; *) exit 65 ;; esac
            asset_name="code-server_${version}_${architecture}.deb"
            package="$temporary/code-server.deb"
            url="https://github.com/coder/code-server/releases/download/v${version}/${asset_name}"
            digest=$(jq -r --arg name "$asset_name" \
                '\''.assets[] | select(.name == $name) | (.digest // empty)'\'' "$release_json" | head -n1)
            curl -fL --proto "=https" --proto-redir "=https" "$url" -o "$package"
            if [[ "$digest" == sha256:* ]]; then
                expected_sha=${digest#sha256:}
                actual_sha=$(sha256sum "$package" | awk '\''{print $1}'\'')
                test "$actual_sha" = "$expected_sha"
            elif [[ -n "$digest" ]]; then
                printf "Unsupported publisher digest: %s\n" "$digest" >&2
                exit 65
            fi
            test "$(dpkg-deb -f "$package" Package)" = code-server
            test "$(dpkg-deb -f "$package" Architecture)" = "$architecture"
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$package"
            install -d -m 0755 /usr/local/share
            printf "%s\n" "$version" > /usr/local/share/orynquix-code-server-version
        '
}

install_selected_browser() {
    case "$ORYNQUIX_BROWSER" in
        none) log_success 'Linux browser installation was skipped by user choice' ;;
        firefox) install_firefox_repository ;;
        chromium)
            if run_in_ubuntu /bin/sh -c 'command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1'; then
                log_success 'Existing compatible Chromium installation preserved'
            else
                log_warn 'Ubuntu Chromium is Snap-based and is not reliable under standard PRoot.'
                log_warn 'Installing the signed Mozilla Firefox DEB instead and recording the fallback.'
                install_firefox_repository
                ini_set_value "$ORYNQUIX_CONFIG_FILE" applications browser firefox
                ORYNQUIX_BROWSER=firefox
            fi
            ;;
        both)
            install_firefox_repository
            if run_in_ubuntu /bin/sh -c 'command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1'; then
                log_success 'Existing compatible Chromium installation preserved'
            else
                log_warn 'Chromium is unavailable without Snap; Firefox is the verified PRoot browser.'
                ini_set_value "$ORYNQUIX_CONFIG_FILE" applications browser firefox
                ORYNQUIX_BROWSER=firefox
            fi
            ;;
    esac
}

install_selected_editor() {
    case "$ORYNQUIX_EDITOR" in
        none) log_success 'Coding editor installation was skipped by user choice' ;;
        auto)
            if install_vscode_repository; then
                log_success 'VS Code desktop compatibility launcher installed'
            else
                log_warn 'VS Code desktop installation failed; installing code-server fallback.'
                install_code_server_release
                ini_set_value "$ORYNQUIX_CONFIG_FILE" applications editor code-server
                ORYNQUIX_EDITOR=code-server
            fi
            ;;
        vscode) install_vscode_repository ;;
        code-server) install_code_server_release ;;
        both)
            if install_vscode_repository; then
                install_code_server_release
            else
                log_warn 'VS Code desktop installation failed; continuing with verified code-server.'
                install_code_server_release
                ini_set_value "$ORYNQUIX_CONFIG_FILE" applications editor code-server
                ORYNQUIX_EDITOR=code-server
            fi
            ;;
    esac
}

verify_development_tools() {
    collect_development_packages
    (( ${#ORYNQUIX_SELECTED_PACKAGES[@]} )) || return 0
    local package
    for package in "${ORYNQUIX_SELECTED_PACKAGES[@]}"; do
        ubuntu_package_installed "$package" || return 1
    done
}

install_selected_applications() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && {
        log_info "[dry-run] Would install browser=$ORYNQUIX_BROWSER, editor=$ORYNQUIX_EDITOR, development=$ORYNQUIX_DEV_TOOLS"
        return 0
    }
    install_development_tools
    install_selected_browser
    install_selected_editor
}

verify_selected_applications() {
    [[ "$ORYNQUIX_DRY_RUN" == 1 ]] && return 0
    local browser editor
    browser=$(config_get applications browser)
    editor=$(config_get applications editor)
    verify_development_tools || return 1
    case "$browser" in
        none) ;;
        firefox) run_in_ubuntu /bin/sh -c 'command -v orynquix-firefox >/dev/null 2>&1' || return 1 ;;
        chromium) run_in_ubuntu /bin/sh -c 'command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1' || return 1 ;;
        both)
            run_in_ubuntu /bin/sh -c \
                'command -v orynquix-firefox >/dev/null 2>&1 && { command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; }' || return 1
            ;;
    esac
    case "$editor" in
        none) ;;
        auto|vscode) run_in_ubuntu /bin/sh -c 'command -v orynquix-code >/dev/null 2>&1' || return 1 ;;
        code-server) run_in_ubuntu /bin/sh -c 'command -v code-server >/dev/null 2>&1' || return 1 ;;
        both)
            run_in_ubuntu /bin/sh -c 'command -v orynquix-code >/dev/null 2>&1 && command -v code-server >/dev/null 2>&1' || return 1
            ;;
    esac
}
