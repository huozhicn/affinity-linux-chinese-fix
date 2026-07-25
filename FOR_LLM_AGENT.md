# 给 LLM Agent 的任务书

把下面整段（从「任务」到文末）复制粘贴给任意 LLM Agent（Kimi Code、Claude Code、Cursor 等），Agent 即可自主完成修复，无需人工干预技术细节。

任务书中已包含全部已确诊的根因和禁区，Agent 不需要再重新排查。

---

# 任务：修复 AffinityLinux AppImage 中文界面方块（"口口"）

## 背景（已确诊结论，请勿再走以下弯路）

- Affinity v3 界面是 WPF / DirectWrite 渲染。修改 Wine 注册表的 `FontSubstitutes`、`FontLink`（GDI 层面）对它**完全无效**，不要尝试。
- WPF 的中文回退依赖 `C:\Windows\Fonts\GlobalUserInterface.CompositeFont`，简体中文（zh-Hans）的汉字回退目标是 `Microsoft YaHei` → `SimSun`。Wine prefix 中没有这些真实 Windows 字体，因此全部渲染为方块。
- **禁止**用开源字体（Noto CJK、文泉驿等）改名伪装成 `Microsoft YaHei`：实测 Wine 能找到并加载，但 Affinity 会在 `Serif.Affinity.Application.PostLoad()` 抛 `NullReferenceException` 崩溃（CFF、TrueType、TTC 各种形式均如此）。**必须使用从真实 Windows 安装中提取的字体文件。**
- 该 AppImage 的 `system.reg` **文件顶部**有一个无效区段：
  ```
  [HKEY_LOCAL_MACHINESoftwareMicrosoftWindows NTCurrentVersionFonts]
  ```
  它是打包脚本手工附加的，Wine **不会**把它当作字体注册键，写进去不生效且无任何报错。真正的字体注册键是：
  ```
  [Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]
  ```
  注册条目必须插入到该键的 `#time=` 行之后。

## 环境

- Wine prefix 默认路径：`~/.AffinityLinux-Appimage`。若 `system.reg` 不存在，询问用户实际路径。
- 字体来源：询问用户 Windows 字体所在目录（例如已挂载的 Windows 分区 `/media/.../Windows/Fonts`，或用户事先复制好的目录）。不要尝试从网上下载字体（版权问题）。

## 需要的字体文件（按存在情况注册，核心为前 4 个）

```
msyh.ttc   （Microsoft YaHei + Microsoft YaHei UI，必须）
msyhbd.ttc （Microsoft YaHei Bold + UI Bold，必须）
msyhl.ttc  （Light，可选）
simsun.ttc （SimSun + NSimSun，必须）
simhei.ttf simkai.ttf simfang.ttf（可选）
simsunb.ttf SimsunExtG.ttf（可选）
Deng.ttf Dengb.ttf Dengl.ttf（可选）
segoeui.ttf segoeuib.ttf segoeuii.ttf segoeuiz.ttf segoeuil.ttf segoeuisl.ttf（可选）
```

## 执行步骤

1. 确认 Affinity 未运行：`pgrep -f "Affinity[.]exe"`。如在运行，先关闭，并等待 wineserver 退出（wineserver 退出时会重写 `system.reg`，必须在其关闭后再编辑）。注意：`pkill -f` 的模式不要匹配到你自己的 shell 命令行（可用 `pkill -f "Affinity[.]exe"` 这种写法）。
2. `mkdir -p <prefix>/drive_c/winefonts`，把上述字体复制进去（保持文件名不变）。
3. 备份：`cp <prefix>/system.reg <prefix>/system.reg.bak-$(date +%Y%m%d-%H%M%S)`。
4. 用 python3 编辑 `system.reg`：在 `[Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]` 键的 `#time=` 行之后插入条目；已存在的同名条目跳过（幂等）。注册条目只针对实际复制成功的文件。格式要点：
   - 值为字体文件的 Linux 绝对路径加 `Z:` 前缀，路径分隔符用**成对反斜杠**；
   - ttc 内含多个字体面时，每个面单独注册一条、指向同一个 ttc 文件。

   完整条目（文件名→注册名）：

   | 文件 | 注册条目名 |
   |---|---|
   | msyh.ttc | `Microsoft YaHei (TrueType)`、`Microsoft YaHei UI (TrueType)` |
   | msyhbd.ttc | `Microsoft YaHei Bold (TrueType)`、`Microsoft YaHei UI Bold (TrueType)` |
   | msyhl.ttc | `Microsoft YaHei Light (TrueType)`、`Microsoft YaHei UI Light (TrueType)` |
   | simsun.ttc | `SimSun (TrueType)`、`NSimSun (TrueType)` |
   | simsunb.ttf | `SimSun-ExtB (TrueType)` |
   | SimsunExtG.ttf | `SimSun-ExtG (TrueType)` |
   | simhei.ttf | `SimHei (TrueType)` |
   | simkai.ttf | `KaiTi (TrueType)` |
   | simfang.ttf | `FangSong (TrueType)` |
   | Deng.ttf / Dengb.ttf / Dengl.ttf | `DengXian (TrueType)` / `DengXian Bold (TrueType)` / `DengXian Light (TrueType)` |
   | segoeui.ttf 等 6 个 | `Segoe UI (TrueType)` / `Segoe UI Bold (TrueType)` / `Segoe UI Italic (TrueType)` / `Segoe UI Bold Italic (TrueType)` / `Segoe UI Light (TrueType)` / `Segoe UI Semilight (TrueType)` |

   示例（实际写入文件的样子）：
   ```
   "Microsoft YaHei (TrueType)"="Z:\\home\\wang\\.AffinityLinux-Appimage\\drive_c\\winefonts\\msyh.ttc"
   ```

5. 启动 AppImage（`nohup <AppImage路径> >/tmp/affinity-test.log 2>&1 &`），等待 60–90 秒，验证：
   - `pgrep -f "Affinity[.]exe"` 进程存活；
   - 日志中无 `Unhandled Exception`。
6. 请用户目视确认界面中文显示正常。

## 注意事项

- 不要把字体文件或重新打包的 AppImage 发布到公开仓库（侵犯 Microsoft/方正/Serif 版权）。
- 如果修复后仍有个别界面元素方块，用 `WINEDEBUG=+dwrite` 启动并抓取 `dwritefontcollection_FindFamilyName` 日志，看实际探测的是哪个字体族名，再补注册对应字体；诊断完务必用无调试方式重新启动验证（重度跟踪本身可能导致进程不稳定）。
- prefix 被重置后中文会再次失效，按本步骤重跑即可。
