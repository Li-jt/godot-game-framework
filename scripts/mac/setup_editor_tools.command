#!/bin/bash
# ============================================================
# GF Editor Tools — macOS 同步脚本（双击运行）
# ============================================================
# 双击此文件即可自动将框架编辑器工具安装到游戏项目中。
# 脚本会自动向上查找 project.godot 来定位项目根目录。
# ============================================================

set -e

# ---- 推断路径 ----
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# 从脚本所在目录向上查找 project.godot
FIND_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR=""
while [ "$FIND_DIR" != "/" ]; do
    if [ -f "$FIND_DIR/project.godot" ]; then
        PROJECT_DIR="$FIND_DIR"
        break
    fi
    FIND_DIR="$(dirname "$FIND_DIR")"
done

if [ -z "$PROJECT_DIR" ]; then
    clear 2>/dev/null || printf '\033c'
    echo "╔══════════════════════════════════════════╗"
    echo "║   GF Editor Tools — 同步脚本 (macOS)    ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  [错误] 找不到 project.godot"
    echo ""
    echo "  脚本通过向上搜索 project.godot 来定位项目根。"
    echo "  请确认："
    echo "    1. 框架代码放在了游戏项目的子目录中（如 src/framework/）"
    echo "    2. 游戏项目根目录下有 project.godot"
    echo ""
    read -p "  按回车退出..."
    exit 1
fi

# 框架根 = 脚本所在目录向上到 src/framework/ 这一级
# 即从脚本目录开始向上走，直到找到"包含 addons/gf_editor_tools 的目录"
FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"
while [ "$FRAMEWORK_DIR" != "/" ]; do
    if [ -d "$FRAMEWORK_DIR/addons/gf_editor_tools" ]; then
        break
    fi
    FRAMEWORK_DIR="$(dirname "$FRAMEWORK_DIR")"
done

if [ ! -d "$FRAMEWORK_DIR/addons/gf_editor_tools" ]; then
    clear 2>/dev/null || printf '\033c'
    echo "╔══════════════════════════════════════════╗"
    echo "║   GF Editor Tools — 同步脚本 (macOS)    ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  [错误] 找不到 addons/gf_editor_tools"
    echo "  请确认框架目录结构完整。"
    read -p "  按回车退出..."
    exit 1
fi

SRC_ADDON="$FRAMEWORK_DIR/addons/gf_editor_tools"
DST_ADDON="$PROJECT_DIR/addons/gf_editor_tools"
PROJECT_GODOT="$PROJECT_DIR/project.godot"
PLUGIN_ENTRY="res://addons/gf_editor_tools/plugin.cfg"

# ---- 终端输出 ----
clear 2>/dev/null || printf '\033c'
echo "╔══════════════════════════════════════════╗"
echo "║   GF Editor Tools — 同步脚本 (macOS)    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  项目路径 : $PROJECT_DIR"
echo "  框架路径 : $FRAMEWORK_DIR"
echo ""

# ---- 确认 ----
if [ -d "$DST_ADDON" ]; then
    echo "  [!] 目标位置已存在 gf_editor_tools"
    echo "  [!] $DST_ADDON"
    echo ""
    echo "  覆盖 INSTALL 会丢失该目录下的本地修改。"
    echo "  如果只是要更新版本，选择覆盖是安全的。"
    echo ""
    read -p "  是否覆盖? [y/N] " yn
    case $yn in
        [Yy]* ) ;;
        * )
            echo ""
            echo "  已取消。"
            read -p "  按回车关闭..."
            exit 0
            ;;
    esac
fi

# ---- 确保 addons 目录存在 ----
if [ ! -d "$PROJECT_DIR/addons" ]; then
    mkdir -p "$PROJECT_DIR/addons"
    echo "  已创建 addons/ 目录"
fi

# ---- 步骤 1: 复制 addon ----
echo ""
echo "  [1/2] 复制 addon 文件..."

if [ "$(cd "$SRC_ADDON" 2>/dev/null && pwd)" = "$(cd "$DST_ADDON" 2>/dev/null && pwd)" ]; then
    echo "         源和目标相同，跳过复制"
else
    rm -rf "$DST_ADDON" 2>/dev/null || true
    cp -R "$SRC_ADDON" "$DST_ADDON"
    echo "         已复制到 $DST_ADDON"
fi

# ---- 步骤 2: 启用插件 ----
echo "  [2/2] 启用插件..."

if grep -q "gf_editor_tools" "$PROJECT_GODOT" 2>/dev/null; then
    echo "         插件已处于启用状态"
else
    if grep -q "^\[editor_plugins\]" "$PROJECT_GODOT"; then
        if grep -q "^enabled=PackedStringArray(" "$PROJECT_GODOT"; then
            sed -i '' "s|^enabled=PackedStringArray(|enabled=PackedStringArray(\"$PLUGIN_ENTRY\", |" "$PROJECT_GODOT"
        else
            sed -i '' "/^\[editor_plugins\]/a\\
enabled=PackedStringArray(\"$PLUGIN_ENTRY\")" "$PROJECT_GODOT"
        fi
    else
        echo "" >> "$PROJECT_GODOT"
        echo "[editor_plugins]" >> "$PROJECT_GODOT"
        echo "enabled=PackedStringArray(\"$PLUGIN_ENTRY\")" >> "$PROJECT_GODOT"
    fi
    echo "         已启用 GF Editor Tools"
fi

# ---- 完成 ----
echo ""
echo "  ══════════════════════════════════════════"
echo "  设置完成！"
echo "  重启 Godot 编辑器后，在 FileSystem 中"
echo "  右键 → 新建 → ECS Component 即可使用。"
echo "  ══════════════════════════════════════════"
echo ""
read -p "  按回车关闭..."
