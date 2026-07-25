# Affinity Linux 中文界面修复

修复 [AffinityLinux](https://github.com/ryzendew/Linux-Affinity-Installer) AppImage 版本切换中文界面后，所有中文显示为方块（"口口"）的问题。

> English: This repo fixes the "all Chinese UI text shows as tofu boxes" issue of the Affinity AppImage for Linux. It contains **documentation and a fix script only** — no font files and no Affinity binaries (see [法律与版权](#法律与版权) / Legal below). Jump to [Quick start](#快速开始).

## 问题现象

AppImage 启动正常，但在 设置 → 常规 → 语言 切换为中文后，界面上的中文全部变成方块。

## 根因分析（三个叠加的坑）

1. **GDI 字体替换无效**：Affinity v3 的界面是 WPF（DirectWrite）渲染，Wine 注册表里的 `FontSubstitutes` / `FontLink`（GDI 层）对它完全不起作用。网上常见的 "Wine 中文方块改注册表" 教程在这里无效。

2. **WPF 中文回退依赖真实 Windows 字体**：WPF 通过 `C:\Windows\Fonts\GlobalUserInterface.CompositeFont` 做按语言/字符集的字体回退，简体中文（zh-Hans）的汉字回退目标是 `Microsoft YaHei`、`SimSun`。AppImage 的 Wine prefix 里没有这些字体，于是全部渲染为 `.notdef`（方块）。
   - 注意：**用开源字体改名伪装成 Windows 字体不可行**。实测把 Noto Sans CJK / 文泉驿改名为 `Microsoft YaHei` 后，Wine 确实能找到并加载，但 Affinity 会在 `Serif.Affinity.Application.PostLoad()` 抛出 `NullReferenceException` 崩溃（CFF、TrueType、TTC 各种打包方式均如此）。必须使用真正的 Windows 字体文件。

3. **注册表陷阱**：该 AppImage 的 `system.reg` 文件**顶部**有一个无效区段：
   ```
   [HKEY_LOCAL_MACHINESoftwareMicrosoftWindows NTCurrentVersionFonts]
   ```
   这是打包脚本手工附加的，**Wine 不会把它当作字体注册键**。真正的字体注册键是：
   ```
   [Software\Microsoft\Windows NT\CurrentVersion\Fonts]
   ```
   字体注册写错区段，表现为完全无声无息地不生效。

## 快速开始

前提：一份**你自己合法拥有的** Windows 安装中的字体（双系统分区、另一台 Windows PC 的 `C:\Windows\Fonts` 均可）。

```bash
# 例 1：直接指向挂载好的 Windows 分区
./fix-affinity-chinese.sh /media/usb/Windows/Fonts

# 例 2：先把所需字体复制到某个目录，再指向它
./fix-affinity-chinese.sh ~/my-win-fonts
```

脚本会自动：

1. 从源目录取出所需字体（`msyh.ttc`、`msyhbd.ttc`、`msyhl.ttc`、`simsun.ttc`、`simhei.ttf`、`simkai.ttf`、`simfang.ttf`、`Deng*.ttf`、`segoeui*.ttf` 等，存在才复制，核心要求 `msyh.ttc`）；
2. 复制到 prefix 的 `drive_c/winefonts/`；
3. 备份 `system.reg`（`system.reg.bak-时间戳`）；
4. 把注册条目写入**正确的** Fonts 键（幂等，可重复运行）。

然后启动 Affinity 即可。

如果 prefix 不在默认位置 `~/.AffinityLinux-Appimage`：

```bash
AFFINITY_PREFIX=/你的/prefix 路径 ./fix-affinity-chinese.sh /media/usb/Windows/Fonts
```

## 给 LLM Agent 用

如果你想让自己常用的 LLM Agent（Kimi Code、Claude Code、Cursor 等）来自动完成修复，直接把 [FOR_LLM_AGENT.md](FOR_LLM_AGENT.md) 的内容复制粘贴给它即可。里面写明了全部已确诊根因、禁区和验证步骤，Agent 拿到后可以直接开工，不需要重新排查。

## 手动修复（等价步骤）

1. 关闭 Affinity；
2. 把字体复制到 `~/.AffinityLinux-Appimage/drive_c/winefonts/`；
3. 编辑 `~/.AffinityLinux-Appimage/system.reg`，在 `[Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]` 键的 `#time=` 行之后插入（注意反斜杠成对）：
   ```
   "Microsoft YaHei (TrueType)"="Z:\\home\\<用户名>\\.AffinityLinux-Appimage\\drive_c\\winefonts\\msyh.ttc"
   "Microsoft YaHei UI (TrueType)"="Z:\\home\\<用户名>\\.AffinityLinux-Appimage\\drive_c\\winefonts\\msyh.ttc"
   ```
   其余字体同理；
4. 启动 Affinity。

## 注意事项

- prefix 被重建/重置后需重新运行脚本。
- 该 AppImage 有已知的内存占用过高问题（上游 issue #106），与本修复无关。
- 诊断字体问题时可用 `WINEDEBUG=+font,+dwrite` 启动观察日志（注意：重度跟踪本身可能导致进程不稳定，仅用于诊断）。

## 法律与版权

- 本仓库**只包含文档与脚本**，不包含、也不提供任何字体文件或 Affinity 程序文件。
- `msyh.ttc`（微软雅黑）、`simsun.ttc`（宋体）、`segoeui.ttf`（Segoe UI）等字体的版权归 Microsoft / 方正等厂商所有，**不允许公开再分发**。请使用你自己合法 Windows 安装中的字体，仅供个人使用。
- 同理，请勿重新打包发布包含 Affinity 程序本体或上述字体的 AppImage，那会侵犯 Serif 与字体厂商的版权。

## 参考

- [ryzendew/Linux-Affinity-Installer](https://github.com/ryzendew/Linux-Affinity-Installer) 及其 [Known issues](https://github.com/ryzendew/Linux-Affinity-Installer/blob/main/docs/Known-issues.md)

## License

脚本与文档以 [MIT](LICENSE) 发布（不涉及任何第三方字体/程序文件）。
