#!/usr/bin/env bash
set -euo pipefail

# GNOME loads system-wide XDG autostart entries from this directory.
# Keep this in sync with the working Fedora Fcitx5 autostart entry.
desktop_file='/usr/share/applications/org.fcitx.Fcitx5.desktop'
autostart_file='/etc/xdg/autostart/org.fcitx.Fcitx5.desktop'

if [[ ! -f "$desktop_file" ]]; then
    printf '错误：找不到 Fcitx5 desktop 文件：%s\n' "$desktop_file" >&2
    exit 1
fi

sudo install -Dm644 "$desktop_file" "$autostart_file"
printf '已设置 Fcitx5 自启动：%s\n' "$autostart_file"
