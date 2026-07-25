#!/usr/bin/env bash
# fix-affinity-chinese.sh
# 修复 AffinityLinux AppImage 中文界面方块（口口）问题。
# 用法: ./fix-affinity-chinese.sh <Windows Fonts 目录>
#   例如: ./fix-affinity-chinese.sh /media/usb/Windows/Fonts
#   也可以先把需要的字体文件复制到某个目录，再传该目录路径。
#
# 脚本只做三件事：
#   1. 把所需字体复制到 prefix 的 drive_c/winefonts/
#   2. 备份 system.reg
#   3. 把字体注册写入 *真正的* Fonts 注册键
#      [Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]
#
# 注意：请使用你自己合法 Windows 安装中的字体，脚本不分发任何字体。

set -euo pipefail

PREFIX="${AFFINITY_PREFIX:-$HOME/.AffinityLinux-Appimage}"
SRC="${1:-}"

if [ -z "$SRC" ]; then
    echo "用法: $0 <Windows Fonts 目录>" >&2
    echo "示例: $0 /media/usb/Windows/Fonts" >&2
    exit 1
fi
if [ ! -d "$SRC" ]; then
    echo "错误: 目录不存在: $SRC" >&2
    exit 1
fi
if [ ! -f "$PREFIX/system.reg" ]; then
    echo "错误: 找不到 Affinity prefix: $PREFIX" >&2
    echo "如果 prefix 在别处, 用 AFFINITY_PREFIX=/path/to/prefix $0 ... 指定" >&2
    exit 1
fi
if pgrep -f "Affinity\.exe" >/dev/null 2>&1; then
    echo "错误: Affinity 正在运行, 请先关闭再执行本脚本" >&2
    exit 1
fi

# 需要的字体（在源目录中按大小写不敏感查找）
WANTED=(
    msyh.ttc msyhbd.ttc msyhl.ttc
    simsun.ttc simsunb.ttf SimsunExtG.ttf
    simhei.ttf simkai.ttf simfang.ttf
    Deng.ttf Dengb.ttf Dengl.ttf
    segoeui.ttf segoeuib.ttf segoeuii.ttf
    segoeuiz.ttf segoeuil.ttf segoeuisl.ttf
)

DESTDIR="$PREFIX/drive_c/winefonts"
mkdir -p "$DESTDIR"

declare -A FOUND=()
MISSING=()
for name in "${WANTED[@]}"; do
    hit=$(find "$SRC" -maxdepth 1 -iname "$name" -type f | head -n1 || true)
    if [ -n "$hit" ]; then
        cp -f "$hit" "$DESTDIR/$name"
        FOUND["$name"]="$DESTDIR/$name"
    else
        MISSING+=("$name")
    fi
done

if [ -z "${FOUND[msyh.ttc]:-}" ]; then
    echo "错误: 在 $SRC 中找不到核心字体 msyh.ttc（微软雅黑）" >&2
    echo "请确认传入的是 Windows 的 C:\\Windows\\Fonts 目录" >&2
    exit 1
fi

[ ${#MISSING[@]} -gt 0 ] && echo "提示: 以下可选字体未找到，已跳过: ${MISSING[*]}"

BACKUP="$PREFIX/system.reg.bak-$(date +%Y%m%d-%H%M%S)"
cp "$PREFIX/system.reg" "$BACKUP"
echo "已备份注册表: $BACKUP"

# 把注册条目写入真正的 Fonts 键（幂等：已存在则跳过）
PREFIX="$PREFIX" python3 - <<'PYEOF'
import os

prefix = os.environ["PREFIX"]
reg_path = os.path.join(prefix, "system.reg")

ENTRIES = [
    ("Microsoft YaHei (TrueType)",              "msyh.ttc"),
    ("Microsoft YaHei UI (TrueType)",           "msyh.ttc"),
    ("Microsoft YaHei Bold (TrueType)",         "msyhbd.ttc"),
    ("Microsoft YaHei UI Bold (TrueType)",      "msyhbd.ttc"),
    ("Microsoft YaHei Light (TrueType)",        "msyhl.ttc"),
    ("Microsoft YaHei UI Light (TrueType)",     "msyhl.ttc"),
    ("SimSun (TrueType)",                       "simsun.ttc"),
    ("NSimSun (TrueType)",                      "simsun.ttc"),
    ("SimSun-ExtB (TrueType)",                  "simsunb.ttf"),
    ("SimSun-ExtG (TrueType)",                  "SimsunExtG.ttf"),
    ("SimHei (TrueType)",                       "simhei.ttf"),
    ("KaiTi (TrueType)",                        "simkai.ttf"),
    ("FangSong (TrueType)",                     "simfang.ttf"),
    ("DengXian (TrueType)",                     "Deng.ttf"),
    ("DengXian Bold (TrueType)",                "Dengb.ttf"),
    ("DengXian Light (TrueType)",               "Dengl.ttf"),
    ("Segoe UI (TrueType)",                     "segoeui.ttf"),
    ("Segoe UI Bold (TrueType)",                "segoeuib.ttf"),
    ("Segoe UI Italic (TrueType)",              "segoeuii.ttf"),
    ("Segoe UI Bold Italic (TrueType)",         "segoeuiz.ttf"),
    ("Segoe UI Light (TrueType)",               "segoeuil.ttf"),
    ("Segoe UI Semilight (TrueType)",           "segoeuisl.ttf"),
]

destdir = os.path.join(prefix, "drive_c", "winefonts")
# system.reg 中反斜杠需成对出现，如 "Z:\\home\\user\\...\\msyh.ttc"
zbase = "Z:" + destdir.replace("/", "\\\\")

with open(reg_path, encoding="utf-8") as f:
    lines = f.read().splitlines(keepends=True)

new_entries = []
for name, fname in ENTRIES:
    if not os.path.exists(os.path.join(destdir, fname)):
        continue  # 只注册实际复制成功的字体
    value = f'"{name}"="{zbase}\\\\{fname}"\n'
    if not any(l.startswith(f'"{name}"=') for l in lines):
        new_entries.append(value)

if not new_entries:
    print("注册表条目已存在，无需修改")
    raise SystemExit(0)

anchor = "[Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion\\\\Fonts]"
for i, line in enumerate(lines):
    if line.startswith(anchor):
        assert lines[i + 1].startswith("#time="), "Fonts 键格式异常"
        lines[i + 2:i + 2] = new_entries
        break
else:
    raise SystemExit("错误: 在 system.reg 中找不到真正的 Fonts 注册键")

with open(reg_path, "w", encoding="utf-8") as f:
    f.write("".join(lines))

print(f"已写入 {len(new_entries)} 条字体注册")
PYEOF

echo ""
echo "完成！现在启动 Affinity，中文界面应正常显示。"
echo "如果日后 prefix 被重置导致中文再次失效，重新运行本脚本即可。"
