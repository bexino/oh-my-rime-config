#!/usr/bin/env python3
"""Install Mintimate's Rime configuration for the invoking desktop user."""

from __future__ import annotations

import os
import pwd
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


REPOSITORY = "https://github.com/Mintimate/oh-my-rime.git"
SYSTEM_PACKAGES = [
    "wl-clipboard",
    "fcitx5-rime",
    "librime-lua",
    "librime-tools",
]


def fail(message: str) -> None:
    print(f"\n-失败：{message}", file=sys.stderr)
    raise SystemExit(1)


def account_from_uid(uid: int) -> pwd.struct_passwd:
    try:
        return pwd.getpwuid(uid)
    except KeyError:
        fail(f"找不到 UID 为 {uid} 的用户")


def target_account() -> pwd.struct_passwd:
    requested = os.environ.get("TARGET_USER") or os.environ.get("SUDO_USER")
    if requested and requested != "root":
        try:
            return pwd.getpwnam(requested)
        except KeyError:
            fail(f"找不到目标用户：{requested}")

    sudo_uid = os.environ.get("SUDO_UID", "")
    if sudo_uid.isdigit() and int(sudo_uid) != 0:
        return account_from_uid(int(sudo_uid))

    try:
        return account_from_uid(os.stat(__file__).st_uid)
    except OSError as error:
        fail(f"无法确定脚本所有者：{error}")


def run(command: list[str], *, cwd: Path | None = None) -> None:
    try:
        subprocess.run(command, cwd=cwd, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"命令执行失败：{' '.join(command)}；{error}")


def chown_tree(path: Path, uid: int, gid: int) -> None:
    for child in [path, *path.rglob("*")]:
        try:
            os.chown(child, uid, gid, follow_symlinks=False)
        except OSError as error:
            fail(f"无法设置文件所有者：{child}；{error}")


def run_as_target(account: pwd.struct_passwd, command: list[str]) -> None:
    runtime_dir = Path("/run/user") / str(account.pw_uid)
    environment = os.environ.copy()
    environment.update(
        {
            "HOME": account.pw_dir,
            "USER": account.pw_name,
            "LOGNAME": account.pw_name,
            "XDG_RUNTIME_DIR": str(runtime_dir),
            "DBUS_SESSION_BUS_ADDRESS": f"unix:path={runtime_dir}/bus",
        }
    )
    try:
        subprocess.run(
            ["runuser", "--user", account.pw_name, "--", *command],
            check=True,
            env=environment,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"以用户 {account.pw_name} 执行命令失败：{error}")


def main() -> None:
    if os.geteuid() != 0:
        fail("请从 install.sh 启动，或使用 sudo -i 运行此脚本")

    account = target_account()
    target_home = Path(account.pw_dir)
    rime_dir = target_home / ".local" / "share" / "fcitx5" / "rime"
    themes_dir = target_home / ".local" / "share" / "fcitx5" / "themes"

    print("### Oh-My-RIME 薄荷拼音自动安装工具 ###")
    print(f"目标用户：{account.pw_name}")

    print("\n-正在安装 Fcitx5-Rime 后端")
    run(["dnf", "install", "-y", *SYSTEM_PACKAGES])

    with tempfile.TemporaryDirectory(prefix="oh-my-rime-") as temporary:
        temporary_dir = Path(temporary)
        checkout = temporary_dir / "source"
        print("\n-正在下载薄荷拼音配置及万象词库")
        run(["git", "clone", "--depth=1", REPOSITORY, str(checkout)])

        backup_dir = temporary_dir / "backup"
        if rime_dir.exists():
            backup_dir.mkdir()
            for item in (rime_dir / "user.yaml", *rime_dir.glob("*.userdb")):
                if item.is_dir():
                    shutil.copytree(item, backup_dir / item.name)
                elif item.is_file():
                    shutil.copy2(item, backup_dir / item.name)

        print("\n-正在导入薄荷拼音配置")
        themes_dir.mkdir(parents=True, exist_ok=True)
        if rime_dir.exists():
            shutil.rmtree(rime_dir)
        shutil.copytree(checkout, rime_dir)

        if backup_dir.exists():
            for item in backup_dir.iterdir():
                destination = rime_dir / item.name
                if item.is_dir():
                    shutil.copytree(item, destination)
                else:
                    shutil.copy2(item, destination)

        chown_tree(rime_dir, account.pw_uid, account.pw_gid)
        chown_tree(themes_dir, account.pw_uid, account.pw_gid)

    print("\n-正在重启目标用户的 Fcitx5")
    if shutil.which("pkill"):
        subprocess.run(["pkill", "-u", str(account.pw_uid), "-x", "fcitx5"], check=False)
    run_as_target(account, ["fcitx5", "-d"])
    print("\n-薄荷拼音和万象词库配置完成！")


if __name__ == "__main__":
    main()
