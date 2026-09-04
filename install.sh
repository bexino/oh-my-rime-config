#!/usr/bin/env bash
set -uo pipefail

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")" || {
    printf '错误：无法解析脚本路径。\n' >&2
    exit 1
}
SCRIPT_DIR="$(dirname -- "$SCRIPT_PATH")"

if [[ "$(id -u)" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        printf '错误：找不到 sudo。\n' >&2
        exit 1
    fi
    exec sudo -i -- "$SCRIPT_PATH" "$@"
fi

resolve_user_from_uid() {
    local uid="$1"
    getent passwd "$uid" | awk -F: 'NR == 1 { print $1 }'
}

TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == root ]]; then
    if [[ "${SUDO_UID:-0}" =~ ^[0-9]+$ && "${SUDO_UID:-0}" -ne 0 ]]; then
        TARGET_USER="$(resolve_user_from_uid "$SUDO_UID")"
    else
        OWNER_UID="$(stat -c '%u' -- "$SCRIPT_PATH" 2>/dev/null || printf '0')"
        if [[ "$OWNER_UID" =~ ^[0-9]+$ && "$OWNER_UID" -ne 0 ]]; then
            TARGET_USER="$(resolve_user_from_uid "$OWNER_UID")"
        fi
    fi
fi

if [[ -z "$TARGET_USER" ]]; then
    printf '错误：无法确定原登录用户。请从普通用户账户运行此脚本。\n' >&2
    exit 1
fi

TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | awk -F: 'NR == 1 { print $6 }')"
if [[ -z "$TARGET_UID" || -z "$TARGET_HOME" || "$TARGET_HOME" == / ]]; then
    printf '错误：无法安全确定目标用户目录：%s\n' "$TARGET_USER" >&2
    exit 1
fi

run_python_script() {
    local script="$1"
    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        printf '错误：找不到脚本：%s\n' "$script" >&2
        return 1
    fi
    TARGET_USER="$TARGET_USER" TARGET_UID="$TARGET_UID" TARGET_HOME="$TARGET_HOME" \
        python3 "$SCRIPT_DIR/$script"
}

post_action() {
    local choice
    while true; do
        printf '\n1. 返回主页\n2. 退出脚本\n'
        read -r -p '请选择：' choice || return 1
        case "$choice" in
            1) return 0 ;;
            2) return 1 ;;
            *) printf '输入无效，请输入 1 或 2。\n' ;;
        esac
    done
}

configure_rime() {
    printf '\n正在配置薄荷拼音和万象词库……\n'
    if run_python_script oh-my-rime-config.py; then
        printf '\n正在设置 Fcitx5 自启动……\n'
        if [[ -x "$SCRIPT_DIR/set-fcitx5-autoboot.sh" ]]; then
            if "$SCRIPT_DIR/set-fcitx5-autoboot.sh"; then
                printf '薄荷拼音、万象词库和 Fcitx5 自启动配置完成。\n'
                return 0
            fi
        else
            printf '错误：找不到或无法执行 set-fcitx5-autoboot.sh。\n' >&2
        fi
        printf '自启动配置失败。\n' >&2
        return 1
    fi
    printf '输入法配置失败，未设置自启动。\n' >&2
    return 1
}

remove_ibus() {
    local packages
    mapfile -t packages < <(
        rpm -qa --qf '%{NAME}\n' 2>/dev/null |
            LC_ALL=C sort -u |
            awk '/^ibus($|-)/ { print }'
    )

    if ((${#packages[@]} == 0)); then
        printf '\n未找到已安装的 IBus 软件包。\n'
        return 0
    fi

    printf '\n将尝试卸载：%s\n' "${packages[*]}"
    printf 'Fedora GNOME 可能因 gnome-shell 依赖 ibus-libs 而拒绝此操作。\n'
    dnf remove -y "${packages[@]}"
}

open_kimpanel() {
    local url='https://extensions.gnome.org/extension/261/kimpanel/'
    local runtime_dir="/run/user/$TARGET_UID"
    local dbus_address="unix:path=$runtime_dir/bus"

    printf '\n正在打开 Gnome 扩展页面……\n'
    if sudo -u "$TARGET_USER" env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="$dbus_address" \
        xdg-open "$url" >/dev/null 2>&1; then
        printf '已请求浏览器打开扩展页面。\n'
        return 0
    fi

    printf '无法自动打开浏览器，请手动访问：\n%s\n' "$url"
    return 1
}

main_menu() {
    local choice
    while true; do
        printf '\n1. 配置薄荷拼音+万象词库\n'
        printf '2. 完全卸载ibus（不建议）\n'
        printf '3. 增加Qt/GTK等应用兼容（非必要）\n'
        printf '4. 安装Gnome扩展\n'
        printf '5. 全部卸载\n'
        printf '6. 退出脚本\n'
        read -r -p '请选择：' choice || break

        case "$choice" in
            1)
                configure_rime || true
                post_action || break
                ;;
            2)
                remove_ibus || true
                post_action || break
                ;;
            3)
                run_python_script configure-fcitx5-environment.py || true
                post_action || break
                ;;
            4)
                open_kimpanel || true
                post_action || break
                ;;
            5)
                if [[ ! -x "$SCRIPT_DIR/uninstall.sh" ]]; then
                    printf '错误：找不到或无法执行 uninstall.sh。\n' >&2
                    exit 1
                fi
                "$SCRIPT_DIR/uninstall.sh" || true
                exit 0
                ;;
            6)
                break
                ;;
            *)
                printf '输入无效，请输入 1 到 6。\n'
                ;;
        esac
    done
}

main_menu
