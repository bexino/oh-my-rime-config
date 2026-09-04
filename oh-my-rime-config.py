#!/bin/env python3
#This Script is under GNU GPL v3 Licence
import os
import sys
import subprocess
import time

USER=os.getlogin()    ##获取当前用户名
Github_source="dgithub.xyz"  ##用于选择直接从Github下载还是从Github镜像源下载
just_rime_update=False ##用于判断用户是否只是来更新RIME输入法的

##由于Fcitx5不会自己新建文件夹,所以需要本程序帮它新建一下
os.system(f'mkdir -p /home/{USER}/.local/share/fcitx5/themes')
os.system(f'mkdir -p /home/{USER}/.local/share/fcitx5/rime')

##对成功和失败的函数调用
def success():
    print('-成功!')
def failed():
    print('\n-失败,请自行排查问题!')
    sys.exit(1)

#####以下是主执行代码####

print('###Oh-My-RIME薄荷输入法自动安装工具###')
print()
print('-请在下方输入您的管理员用户密码')
os.system('sudo echo "-提权成功!" && clear')

print('-正在更新系统APT仓库')
os.system('sudo dnf update')

print('\n-正在安装Fcitx5-RIME后端')
if os.system('sudo dnf remove ibus -y && sudo dnf install wl-clipboard fcitx5-rime librime-lua librime-tools -y')!=0:
    failed()
else:success()

print('\n-正在安装git和用于查看发行版的lsb_release工具')
if os.system('sudo dnf install git git-lfs lsb_release -y')!=0:
    failed()
else:success()

print('\n-正在下载薄荷输入法配置')
while True:
    print('-请问您需要通过国内镜像源下载配置(有延迟)还是直接从Github上下载?')
    print('-输入1从国内源下载配置,输入2直接从Github下载配置')
    a=int(input('-您的输入:'))
    if a==1:
        Github_source="dgithub.xyz"
        break;
    elif a==2:
        Github_source="github.com"
        break;
    else:
        print('-输入错误,请重新输入!')
        print()

if os.system(f'rm -rf /home/{USER}/rimecache && cd /home/{USER} && mkdir rimecache && cd rimecache && git clone --depth=1 https://gitee.com/LFRon/rime-wanxiang-mirror.git rime-wanxiang')!=0:
    failed()
else:success()

# 检测用户之前是不是已经安装了RIME,跑这个脚本只是用来更新的还是替换的
if (os.path.exists(f'/home/{USER}/.local/share/fcitx5/rime')):
    # 检测用户安装的RIME是不是万象输入法
    if (os.path.exists(f'/home/{USER}/.local/share/fcitx5/rime/user.yaml') and os.path.exists(f'/home/{USER}/.local/share/fcitx5/rime/wanxiang.userdb')):   
        just_rime_update=True
        print('- 正在备份用户的输入法个人词典:',end="")
        if (os.system(f'mkdir /home/{USER}/.local/share/fcitx5/cache')!=0):failed()
        if (os.system(f'cd /home/{USER}/.local/share/fcitx5/rime && cp -rf user.yaml wanxiang.userdb ../cache && cp -rf en.userdb ../cache')!=0):failed()
        success()

print('\n-正在导入/更新薄荷输入法')
##先删除原先存在的RIME目录
if os.system(f'rm -rf /home/{USER}/.local/share/fcitx5/rime && mkdir -p /home/{USER}/.local/share/fcitx5/rime && cd /home/{USER}/rimecache/rime-wanxiang && cp -a -f * /home/{USER}/.local/share/fcitx5/rime')!=0:
    failed()
else:success()

if (just_rime_update==True):
    print('- 我发现您已经配置过输入法,那么我将只进行更新操作')
    print('- 正在恢复用户词典备份:',end="")
    if (os.system(f'cd /home/{USER}/.local/share/fcitx5 && cp -rf cache/* rime && rm -rf cache')!=0):failed()
    success()
    if (os.system(f'cd /home/{USER}/.local/share/fcitx5 && rm -rf cache')!=0):
        print('- 奇怪了,你的RIME备份怎么不见了,是不是被你删了?不过这不影响脚本运行~')
        time.sleep(1)

print('\n-正在下载KDE风格输入法皮肤')
if os.system(f'cd /home/{USER}/rimecache && git clone https://gitee.com/LFRon/oh-my-rime-fcitx5-skins.git')!=0:
    failed()
else:success()


print('\n-正在解压并导入KDE风格的输入法皮肤(附赠一堆Breeze风格的)')
if os.system(f'cd /home/{USER}/rimecache/oh-my-rime-fcitx5-skins && unzip oh-my-rime-skins.zip && cd oh-my-rime-skins && cp -a -f * /home/{USER}/.local/share/fcitx5/themes')!=0:
    failed()
else:success()


print('\n-正在对/etc/environment进行修改以适应Qt/GTK应用')
f = open('/etc/environment','r')
environment=f.read()
if environment.find('GTK_IM_MODULE')!=-1 or environment.find('QT_IM_MODULE')!=-1:
    print('检测到您已对输入法环境变量进行修改,已跳过')
else:
    print('-正在修改以增加对Qt/GTK等应用的支持')
    os.system('sudo rm /etc/environment.d/fcitx5.conf')  ###删除我之前配置脚本无用的文件
    os.system(f'cd /home/{USER}/rimecache && git clone https://gitee.com/LFRon/fcitx5-env-config-tool.git && cd fcitx5-env-config-tool && sudo python3 fcitx5-envconfig.py')


print('\n-正在清理缓存')
if os.system(f'cd /home/{USER} && sudo rm -r /home/{USER}/rimecache')!=0:
    failed()
else:success()


print('\n-正在重启fcitx5')
os.system('killall fcitx5')
p = subprocess.Popen(['fcitx5'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
time.sleep(4)

os.system('clear')
print('-薄荷输入法(Fcitx5后端)已经配置完成!')

