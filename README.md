# oh-my-rime-config

~~（可能是）终极~~ Linux 输入法解决方案。

## 适用于

- **RPM 系 (e.g. Fedora, RHEL, etc.)**  
  
  已在 Fedora Workstation 44 GNOME + Wayland 测试通过。
  
- DEB 系 (e.g. Ubuntu, Debian, etc.) 无法使用，请知悉！

---

## 快速入门

```bash
(sudo dnf install -y git git-lfs && tmp_dir="$(mktemp -d)" && git clone https://github.com/bexino/oh-my-rime-config.git "$tmp_dir/oh-my-rime-config" && (cd "$tmp_dir/oh-my-rime-config" && sudo -i -- "$PWD/install.sh"); status=$?; if [[ -n "${tmp_dir:-}" ]]; then sudo rm -rf -- "$tmp_dir"; fi; exit "$status")
```

该命令提供用户友好菜单，退出自动清理临时文件。

---

## 脚本内容

1. 安装 Fcitx5 + 薄荷拼音，  
2. 安装万象词库 + 语言模型，  
3. 配置 Fcitx5 自启动。  

---

## 修改配置

```bash
nano ~/.local/share/fcitx5/rime/rime_mint.schema.yaml
```

或使用 gedit：

```bash
gedit ~/.local/share/fcitx5/rime/rime_mint.schema.yaml
```

### 候选词数量

打开配置文件：

```yaml
menu:
  # 候选词个数
  page_size: 9
```

修改成需要的数量即可。

### 模糊音

打开配置文件：

```yaml
    # - derive/^([zcs])h/$1/ # zh, ch, sh => z, c, s
    # - derive/^([zcs])([^h])/$1h$2/ # z, c, s => zh, ch, sh
    # - derive/([aei])n$/$1ng/ # an => ang, en => eng, in => ing
    # - derive/([aei])ng$/$1n/ # ang => an, eng => en, ing => in
    # - derive/([iu])an$/$lan/ # ian => iang, uan => uang
    # - derive/([iu])ang$/$lan/ # iang => ian, uang => uan
```

去除`#`注释即可：

```yaml
    - derive/^([zcs])h/$1/ # zh, ch, sh => z, c, s
    - derive/^([zcs])([^h])/$1h$2/ # z, c, s => zh, ch, sh
    - derive/([aei])n$/$1ng/ # an => ang, en => eng, in => ing
    - derive/([aei])ng$/$1n/ # ang => an, eng => en, ing => in
    - derive/([iu])an$/$1ang/ # ian => iang, uan => uang
    - derive/([iu])ang$/$1an/ # iang => ian, uang => uan
```

> **注意**：原repo中的最后两行（以下为错误示例）：
> 
> ```yaml
> # - derive/([iu])an$/$lan/
> # - derive/([iu])ang$/$lan/
> ```
> 
> `$1ang / $1an` 被写成了 `$lan`，也就是数字 `1` 和字母 `l`  
> 
> 若需 iu 模糊音，建议修正（以上完整示例已修正）。

### 竖排候选词

- [安装 Kimpanel GNOME 扩展](https://extensions.gnome.org/extension/261/kimpanel/) 。

> 若未安装 GNOME 扩展管理器:
> 
> ```bash
> flatpak install flathub com.mattjakeman.ExtensionManager
> ```

安装 [Kimpanel GNOME 扩展](https://extensions.gnome.org/extension/261/kimpanel/) 后：  在属性设置中打开：`Vertical List`。

---

## 已知问题

- 使用现代 GNOME + Wayland 可能导致候选框漂移到屏幕左上角。
  - 解决方案：[安装 Kimpanel GNOME 扩展](https://extensions.gnome.org/extension/261/kimpanel/)。

---

## 注意

- [建议 GNOME 用户安装 Kimpanel GNOME 扩展](https://extensions.gnome.org/extension/261/kimpanel/)  ，  

- 因 ibus 是 GNOME 核心组件，故并不建议卸载 ibus，并可能因 GNOME 依赖而被 DNF 拒绝卸载。

---

## 剪切板

[安装 Clipboard Indicator GNOME 扩展](https://extensions.gnome.org/extension/779/clipboard-indicator/)。

---

## 鸣谢

https://bbs.deepin.org.cn/post/284609  
https://gitee.com/LFRon/oh-my-rime-config-fedora  
https://gitee.com/LFRon/fcitx5-env-config-tool  
https://github.com/amzxyz/rime-wanxiang  
