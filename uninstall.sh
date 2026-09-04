#!/usr/bin/env bash

# Oh-My-RIME 卸载脚本
#
# 本脚本会删除 Fcitx5、Rime 及 ibus-rime，并清理本项目产生的配置、缓存、
# 自启动文件和本项目目录。ibus 本体不会被卸载；dnf autoremove 也会排除
# 所有以 ibus 开头的软件包。

set -u

SCRIPT_PATH="$(readlink -f -- "$0")" || {
    printf '错误：无法解析脚本路径。\n' >&2
    exit 1
}
SCRIPT_DIR="$(dirname -- "$SCRIPT_PATH")"

# sudo -i 会切换 HOME，因此必须在提权后通过 SUDO_USER/SUDO_UID 找回原用户。
if [[ "$(id -u)" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        printf '错误：找不到 sudo，无法以管理员身份运行。\n' >&2
        exit 1
    fi

    printf '此脚本需要管理员权限，将通过 sudo -i 重新执行。\n'
    exec sudo -i -- "$SCRIPT_PATH" "$@"
fi

usage() {
    printf '用法：%s [--yes]\n' "$SCRIPT_PATH"
    printf '  --yes   跳过最终确认，直接执行卸载\n'
}

ASSUME_YES=0
case "${1:-}" in
    '') ;;
    --yes|-y)
        ASSUME_YES=1
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        printf '错误：未知参数：%s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac

resolve_user_from_uid() {
    local uid="$1"
    getent passwd "$uid" | awk -F: 'NR == 1 { print $1 }'
}

# 优先使用 sudo 记录的调用者；直接以 root 执行时，退回到脚本所有者。
TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == root ]]; then
    if [[ "${SUDO_UID:-0}" =~ ^[0-9]+$ && "${SUDO_UID:-0}" -ne 0 ]]; then
        TARGET_USER="$(resolve_user_from_uid "$SUDO_UID")"
    else
        SCRIPT_OWNER_UID="$(stat -c '%u' -- "$SCRIPT_PATH" 2>/dev/null || printf '0')"
        if [[ "$SCRIPT_OWNER_UID" =~ ^[0-9]+$ && "$SCRIPT_OWNER_UID" -ne 0 ]]; then
            TARGET_USER="$(resolve_user_from_uid "$SCRIPT_OWNER_UID")"
        fi
    fi
fi

if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER=root
fi

TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | awk -F: 'NR == 1 { print $6 }')"
if [[ -z "$TARGET_UID" || -z "$TARGET_HOME" || "$TARGET_HOME" == / ]]; then
    printf '错误：无法安全确定要清理的用户主目录。用户：%s\n' "$TARGET_USER" >&2
    exit 1
fi

# 防止变量为空或意外指向根目录后执行递归删除。
remove_path() {
    local path="$1"

    if [[ -z "$path" || "$path" == / ]]; then
        printf '跳过不安全路径：%s\n' "${path:-<空>}" >&2
        FAILURES=1
        return 1
    fi

    if [[ -e "$path" || -L "$path" ]]; then
        if rm -rf -- "$path"; then
            printf '已删除：%s\n' "$path"
        else
            printf '删除失败：%s\n' "$path" >&2
            FAILURES=1
            return 1
        fi
    fi
    return 0
}

remove_matching_files() {
    local root="$1"
    [[ -d "$root" ]] || return 0

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$root" -xdev -maxdepth 1 -type f \
            \( -iname '*fcitx5*' -o -iname '*rime*' -o -iname '*ibus-rime*' \) \
            -print0 2>/dev/null
    )
}

remove_matching_cache_dirs() {
    local root="$1"
    [[ -d "$root" ]] || return 0

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$root" -xdev \( -type d -o -type l \) \
            \( -iname 'fcitx5' -o -iname 'rime' -o -iname 'rimecache' \
               -o -iname 'rime-wanxiang' -o -iname 'ibus-rime' \) \
            -prune \
            -print0 2>/dev/null
    )
}

remove_project_copies() {
    local git_config
    local project_root
    local project_file
    local project_dir
    local artifact

    [[ -d "$TARGET_HOME" ]] || return 0

    # 删除本项目远程仓库的其他普通 git clone。
    while IFS= read -r -d '' git_config; do
        if grep -Eiq \
            '^[[:space:]]*url[[:space:]]*=[[:space:]]*(https://github\.com/bexino/oh-my-rime-config(\.git)?|git@github\.com:bexino/oh-my-rime-config(\.git)?)[[:space:]]*$' \
            "$git_config"; then
            project_root="$(dirname -- "$(dirname -- "$git_config")")"
            remove_path "$project_root"
        fi
    done < <(
        find "$TARGET_HOME" -xdev -type f -path '*/.git/config' -print0 2>/dev/null
    )

    # 也处理已脱离 git 元数据、但仍保留本项目核心文件的副本（例如回收站中的副本）。
    while IFS= read -r -d '' project_file; do
        project_dir="$(dirname -- "$project_file")"
        if [[ -f "$project_dir/LICENSE" && -f "$project_dir/oh-my-rime-config.py" ]]; then
            remove_path "$project_dir"
        fi
    done < <(
        find "$TARGET_HOME" -xdev -type f -name 'oh-my-rime-config.py' -print0 2>/dev/null
    )

    # 清理本项目压缩包及桌面回收站留下的同名元数据。
    while IFS= read -r -d '' artifact; do
        remove_path "$artifact"
    done < <(
        find "$TARGET_HOME" -xdev -type f \
            \( -iname 'oh-my-rime-config*.zip' -o -iname 'oh-my-rime-config*.tar*' \
               -o -iname 'oh-my-rime-config*.trashinfo' \) \
            -print0 2>/dev/null
    )
}

clean_environment_file() {
    local file="$1"
    local temporary_file

    [[ -f "$file" ]] || return 0

    temporary_file="$(mktemp "${file}.uninstall.XXXXXX")" || {
        printf '无法创建临时文件，跳过：%s\n' "$file" >&2
        FAILURES=1
        return 1
    }

    if ! sed -E \
        '/^[[:space:]]*(export[[:space:]]+)?(XMODIFIERS|GTK_IM_MODULE|QT_IM_MODULE|QT_IM_MODULES|SDL_IM_MODULE|CLUTTER_IM_MODULE|GLFW_IM_MODULE|INPUT_METHOD|IMSETTINGS_MODULE|IBUS_ENABLE_SYNC_MODE)[[:space:]]*=.*$/Id' \
        "$file" >"$temporary_file"; then
        rm -f -- "$temporary_file"
        printf '无法清理：%s\n' "$file" >&2
        FAILURES=1
        return 1
    fi

    if cmp -s -- "$file" "$temporary_file"; then
        rm -f -- "$temporary_file"
        return 0
    fi

    chmod --reference="$file" "$temporary_file" 2>/dev/null || true
    chown --reference="$file" "$temporary_file" 2>/dev/null || true
    if mv -f -- "$temporary_file" "$file"; then
        printf '已清理输入法环境变量：%s\n' "$file"
    else
        rm -f -- "$temporary_file"
        printf '清理失败：%s\n' "$file" >&2
        FAILURES=1
        return 1
    fi
}

FAILURES=0

printf '\n即将为用户 %s 删除以下内容：\n' "$TARGET_USER"
printf '  - 所有已安装的 fcitx5、Rime/librime 和 ibus-rime 软件包\n'
printf '  - Fcitx5、Rime、薄荷拼音、万象词库及 IBus 用户配置和缓存\n'
printf '  - Fcitx5/Rime 自启动文件和本项目目录：%s\n' "$SCRIPT_DIR"
printf '  - /etc/environment 中由输入法使用的环境变量\n'
printf '  - DNF 缓存，并在最后执行 sudo dnf autoremove -y（排除 ibus*）\n'
printf '\n注意：本项目目录及本脚本会被删除，删除后不能依靠本脚本恢复。\n'

if [[ "$ASSUME_YES" -ne 1 ]]; then
    printf '如果确定继续，请输入 DELETE： '
    read -r confirmation || confirmation=''
    if [[ "$confirmation" != DELETE ]]; then
        printf '已取消，未执行卸载。\n'
        exit 0
    fi
fi

printf '\n正在停止当前用户的 Fcitx5 进程……\n'
if command -v pkill >/dev/null 2>&1; then
    pkill -u "$TARGET_UID" -x fcitx5 2>/dev/null || true
fi

printf '正在清理输入法环境变量……\n'
clean_environment_file /etc/environment
clean_environment_file "$TARGET_HOME/.config/environment.d/fcitx5.conf"
clean_environment_file "$TARGET_HOME/.config/environment.d/rime.conf"
clean_environment_file "$TARGET_HOME/.config/environment.d/ibus.conf"

printf '正在删除系统级输入法配置和自启动文件……\n'
for path in \
    /etc/xdg/fcitx5 \
    /etc/fcitx5 \
    /etc/rime \
    /etc/X11/xinit/xinput.d/fcitx5.conf \
    /etc/xdg/autostart/org.fcitx.Fcitx5.desktop \
    /etc/xdg/autostart/fcitx5.desktop \
    /etc/xdg/autostart/fcitx5-autostart.desktop \
    /etc/environment.d/fcitx5.conf \
    /etc/environment.d/rime.conf \
    /etc/environment.d/ibus.conf \
    /etc/environment.d/ibus-rime.conf \
    /etc/profile.d/fcitx5.sh \
    /etc/profile.d/fcitx5.bash \
    /etc/profile.d/rime.sh \
    /etc/profile.d/ibus-rime.sh \
    /var/cache/fcitx5 \
    /var/cache/rime \
    /var/cache/ibus-rime \
    /var/lib/fcitx5 \
    /var/lib/rime; do
    remove_path "$path"
done
remove_matching_files /etc/xdg/autostart
remove_matching_files /etc/environment.d

printf '正在删除用户级输入法配置和缓存……\n'
for path in \
    "$TARGET_HOME/.config/fcitx5" \
    "$TARGET_HOME/.local/share/fcitx5" \
    "$TARGET_HOME/.cache/fcitx5" \
    "$TARGET_HOME/.config/rime" \
    "$TARGET_HOME/.local/share/rime" \
    "$TARGET_HOME/.cache/rime" \
    "$TARGET_HOME/.config/ibus" \
    "$TARGET_HOME/.local/share/ibus/rime" \
    "$TARGET_HOME/.cache/ibus" \
    "$TARGET_HOME/.config/ibus-rime" \
    "$TARGET_HOME/.local/share/ibus-rime" \
    "$TARGET_HOME/.cache/ibus-rime" \
    "$TARGET_HOME/.config/environment.d/ibus.conf" \
    "$TARGET_HOME/.cache/rimecache" \
    "$TARGET_HOME/.cache/rime-wanxiang" \
    "$TARGET_HOME/rimecache" \
    "$TARGET_HOME/rime-wanxiang"; do
    remove_path "$path"
done
remove_matching_files "$TARGET_HOME/.config/autostart"
remove_matching_files "$TARGET_HOME/.config/environment.d"
remove_matching_cache_dirs "$TARGET_HOME/.cache"

printf '正在查找并删除用户主目录中的万象仓库副本……\n'
while IFS= read -r -d '' path; do
    remove_path "$path"
done < <(
    find "$TARGET_HOME" -xdev -type d \
        \( -name 'rimecache' -o -name 'rime-wanxiang' \) \
        -prune -print0 2>/dev/null
)

# 处理用户在 /tmp 或 /var/tmp 中留下的同名仓库，但只处理目标用户拥有的目录。
for temporary_root in /tmp /var/tmp; do
    [[ -d "$temporary_root" ]] || continue
    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$temporary_root" -xdev -uid "$TARGET_UID" -type d \
            \( -name 'rimecache' -o -name 'rime-wanxiang' \) \
            -prune -print0 2>/dev/null
    )
done

printf '正在查询并卸载 Fcitx5、Rime 和 ibus-rime 软件包……\n'
if ! command -v rpm >/dev/null 2>&1 || ! command -v dnf >/dev/null 2>&1; then
    printf '错误：找不到 rpm 或 dnf，无法卸载软件包。\n' >&2
    FAILURES=1
else
    # 先保护 ibus，再删除 ibus-rime，避免 ibus 被当作 ibus-rime 的孤立依赖。
    if rpm -q ibus >/dev/null 2>&1; then
        if ! dnf mark install ibus >/dev/null 2>&1; then
            # 兼容没有 dnf mark 子命令的环境；对已安装包执行 install 不会重复安装。
            dnf install -y ibus >/dev/null 2>&1 || {
                printf '警告：无法将 ibus 标记为用户安装，将继续但会依靠 autoremove 的排除项保护。\n' >&2
            }
        fi
    fi

    mapfile -t input_method_packages < <(
        rpm -qa --qf '%{NAME}\n' 2>/dev/null |
            LC_ALL=C grep -E '^(fcitx5($|-)|librime($|-)|rime($|-)|ibus-rime($|-))' |
            LC_ALL=C sort -u
    )

    if ((${#input_method_packages[@]} > 0)); then
        printf '将卸载：%s\n' "${input_method_packages[*]}"
        if ! dnf remove -y "${input_method_packages[@]}"; then
            printf '软件包卸载过程返回失败。\n' >&2
            FAILURES=1
        fi
    else
        printf '未找到匹配的已安装软件包。\n'
    fi
fi

printf '正在清理 DNF 缓存……\n'
if command -v dnf >/dev/null 2>&1; then
    if ! dnf clean all; then
        printf '清理 DNF 缓存失败。\n' >&2
        FAILURES=1
    fi
else
    printf '跳过 DNF 缓存清理：找不到 dnf。\n' >&2
    FAILURES=1
fi

printf '正在删除本项目目录及其中生成的所有文件……\n'
if ! cd /; then
    printf '错误：无法切换到安全工作目录，未删除项目目录。\n' >&2
    FAILURES=1
elif [[ "$SCRIPT_DIR" == / || "$SCRIPT_DIR" == "$TARGET_HOME" ]]; then
    printf '错误：项目目录路径不安全，未删除：%s\n' "$SCRIPT_DIR" >&2
    FAILURES=1
else
    remove_project_copies
    remove_path "$SCRIPT_DIR"
fi

printf '正在执行最后的依赖清理：sudo dnf autoremove -y……\n'
if command -v sudo >/dev/null 2>&1 && command -v dnf >/dev/null 2>&1; then
    if ! sudo dnf autoremove -y --exclude='ibus*'; then
        printf 'dnf autoremove 执行失败。\n' >&2
        FAILURES=1
    fi
else
    printf '错误：找不到 sudo 或 dnf，无法执行最后的 autoremove。\n' >&2
    FAILURES=1
fi

if [[ "$FAILURES" -eq 0 ]]; then
    printf '\n卸载完成。ibus 本体已保留。\n'
else
    printf '\n卸载已完成主要步骤，但有一个或多个步骤失败，请查看上面的错误信息。\n' >&2
    exit 1
fi
