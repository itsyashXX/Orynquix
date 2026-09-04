#!/bin/sh
set -eu

wallpaper=/usr/share/backgrounds/orynquix/orynquix-default.png
config="$HOME/.config/orynquix/appearance.ini"
command -v xfconf-query >/dev/null 2>&1 || exit 0

config_value() {
    key=$1
    awk -F= -v wanted="$key" '$1 == wanted {print substr($0, index($0, "=") + 1); exit}' "$config" 2>/dev/null
}

theme=$(config_value theme)
ui_scale=$(config_value ui_scale)
compositor=$(config_value compositor)
case "$theme" in
    orynquix-light) gtk_theme=Adwaita ;;
    orynquix-dark|'') gtk_theme=Adwaita-dark ;;
    *) exit 65 ;;
esac
case "$ui_scale" in
    1|1.0|'') dpi=96; panel_size=42 ;;
    1.25) dpi=120; panel_size=52 ;;
    1.5) dpi=144; panel_size=63 ;;
    2|2.0) dpi=192; panel_size=84 ;;
    *) exit 65 ;;
esac
case "$compositor" in true|'') compositor=true ;; false) compositor=false ;; *) exit 65 ;; esac

xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "$gtk_theme" >/dev/null 2>&1 || true
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s Adwaita >/dev/null 2>&1 || true
xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s 'Sans 11' >/dev/null 2>&1 || true
xfconf-query -c xsettings -p /Xft/DPI -n -t int -s "$dpi" >/dev/null 2>&1 || true
xfconf-query -c xfwm4 -p /general/theme -n -t string -s Default >/dev/null 2>&1 || true
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s "$compositor" >/dev/null 2>&1 || true
xfconf-query -c xfce4-panel -p /panels/panel-1/size -s "$panel_size" >/dev/null 2>&1 || true
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
    -n -t string -s "$wallpaper" >/dev/null 2>&1 || true
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style \
    -n -t int -s 5 >/dev/null 2>&1 || true

xfconf-query -c xfce4-desktop -l 2>/dev/null | while IFS= read -r property; do
    case "$property" in
        */last-image) xfconf-query -c xfce4-desktop -p "$property" -s "$wallpaper" >/dev/null 2>&1 || true ;;
    esac
done

xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Primary><Alt>t' \
    -n -t string -s xfce4-terminal >/dev/null 2>&1 || true
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>e' \
    -n -t string -s thunar >/dev/null 2>&1 || true
