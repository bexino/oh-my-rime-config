#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


ENVIRONMENT_FILE = Path('/etc/environment')
LOCAL_CONFIG_SCRIPT = 'fcitx5-envconfig.py'
SCRIPT_DIR = Path(__file__).resolve().parent


def failed(message='请自行排查问题!'):
    print(f'\n-失败,{message}')
    sys.exit(1)


print('\n-正在对/etc/environment进行修改以适应Qt/GTK应用')

try:
    environment = ENVIRONMENT_FILE.read_text(encoding='utf-8')
except OSError as error:
    failed(f'无法读取{ENVIRONMENT_FILE}: {error}')

if 'GTK_IM_MODULE' in environment or 'QT_IM_MODULE' in environment:
    print('检测到您已对输入法环境变量进行修改,已跳过')
    sys.exit(0)

local_config_script = SCRIPT_DIR / LOCAL_CONFIG_SCRIPT
if not local_config_script.is_file():
    failed(f'找不到本地文件{LOCAL_CONFIG_SCRIPT}')

print('-正在修改以增加对Qt/GTK等应用的支持')

# 删除我之前配置脚本无用的文件；即使文件不存在也继续执行配置。
subprocess.run(['sudo', 'rm', '/etc/environment.d/fcitx5.conf'], check=False)

# 使用同目录下的相对文件名运行已存在的本地配置脚本。
result = subprocess.run(
    ['sudo', 'python3', LOCAL_CONFIG_SCRIPT],
    cwd=SCRIPT_DIR,
    check=False,
)
if result.returncode != 0:
    failed()

print('-成功!')
