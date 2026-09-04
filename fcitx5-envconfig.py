#!/bin/env python3
###Please running this script by ROOT!
import os
import sys
import time

f = open('/etc/environment','r+')
env = f.read()
path = '/etc'
f.close()
##判断是否已进行更改###
if  env.find('GTK_IM_MODULE=fcitx')!=-1 or env.find('QT_IM_MODULE=fcitx')!=-1 or env.find('SDL_IM_MODULE=fcitx')!=-1:
    print('-警告:您貌似已经对/etc/environment文件进行了输入法环境变量的修改,请先在/etc/environment删除您对fcitx5的修改!')
    time.sleep(3)
    sys.exit(1)
else:
    print('-正在写入环境变量以实现对Fcitx5的完整支持')
    os.system(f'cd {path} && echo "\nXMODIFIERS=@im=fcitx5" >> environment')
    os.system(f'cd {path} && echo "QT_IM_MODULE=fcitx5" >> environment')
    os.system(f'cd {path} && echo "QT_IM_MODULES=\"wayland;fcitx\"" >> environment')
    os.system(f'cd {path} && echo "GTK_IM_MODULE=fcitx5" >> environment')
    os.system(f'cd {path} && echo "SDL_IM_MODULE=fcitx5" >> environment')
    print('-写入成功!')
