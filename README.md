# oh-my-rime-config

~~（可能是）终极~~ Linux 输入法方案。

## 快速入门

```bash
(sudo dnf install -y git git-lfs && tmp_dir="$(mktemp -d)" && git clone https://github.com/bexino/oh-my-rime-config.git "$tmp_dir/oh-my-rime-config" && (cd "$tmp_dir/oh-my-rime-config" && sudo -i -- "$PWD/install.sh"); status=$?; if [[ -n "${tmp_dir:-}" ]]; then sudo rm -rf -- "$tmp_dir"; fi; exit "$status")
```

## 修改配置

```bash
nano ~/.local/share/fcitx5/rime/rime_mint.schema.yaml
```

或使用 gedit：
```bash
gedit  ~/.local/share/fcitx5/rime/rime_mint.schema.yaml
```

## 脚本内容

1. 安装 Fcitx5 + 薄荷拼音，

2. 安装万象词库 + 语言模型，

3. 配置 Fcitx5 自启动。

## 适用于

RPM系 (e.g. Fedora, RHEL, etc.)

## 注意

- GNOME用户建议安装扩展：https://extensions.gnome.org/extension/261/kimpanel/  ，
- 因 ibus 是 GNOME 核心组件，故并不建议卸载 ibus，并可能因 GNOME 依赖而被 DNF 拒绝卸载。

## 鸣谢

https://bbs.deepin.org.cn/post/284609  
https://gitee.com/LFRon/oh-my-rime-config-fedora  
https://gitee.com/LFRon/fcitx5-env-config-tool  
https://github.com/amzxyz/rime-wanxiang  