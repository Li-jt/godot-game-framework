#!/usr/bin/env python3
"""GF Editor Tools 同步脚本。

将框架自带的编辑器工具 addon 复制到用户项目的 addons/ 目录中，
并自动在 project.godot 中启用该插件。

用法 —— 在游戏项目根目录下运行：

    python3 src/framework/scripts/setup_editor_tools.py

也可以显式指定路径：

    python3 src/framework/scripts/setup_editor_tools.py \\
        --framework src/framework \\
        --project .

"""

import argparse
import os
import re
import shutil
import sys
from pathlib import Path


ADDON_NAME = "gf_editor_tools"
ADDON_ENTRY = f"res://addons/{ADDON_NAME}/plugin.cfg"


def main() -> int:
    parser = argparse.ArgumentParser(description="同步 GF Editor Tools addon")
    parser.add_argument("--framework", type=Path, default=None,
                        help="框架根目录路径（默认根据脚本位置自动推断）")
    parser.add_argument("--project", type=Path, default=Path.cwd(),
                        help="游戏项目根目录（默认为当前目录）")
    parser.add_argument("--no-enable", action="store_true",
                        help="仅复制 addon 文件，不修改 project.godot 启用插件")
    args = parser.parse_args()

    # 推断框架目录
    if args.framework is not None:
        framework_dir = args.framework.resolve()
    else:
        script_dir = Path(__file__).resolve().parent
        framework_dir = script_dir.parent
    project_dir = args.project.resolve()

    src_addon = framework_dir / "addons" / ADDON_NAME
    dst_addon = project_dir / "addons" / ADDON_NAME

    print("=== GF Editor Tools 同步脚本 ===")
    print(f"  框架路径: {framework_dir}")
    print(f"  项目路径: {project_dir}")

    # 检查源目录
    if not src_addon.is_dir():
        print(f"\n[错误] 找不到插件源目录: {src_addon}")
        return 1

    # 复制 addon
    print(f"\n[1/2] 复制 addon 文件...")
    if src_addon.resolve() == dst_addon.resolve():
        print(f"  源与目标相同 ({src_addon})，跳过复制")
    else:
        if dst_addon.exists():
            shutil.rmtree(dst_addon)
            print(f"  已删除旧版本: {dst_addon}")
        shutil.copytree(src_addon, dst_addon)
        print(f"  已复制到: {dst_addon}")

    # 启用插件
    if args.no_enable:
        print(f"\n[跳过] 未修改 project.godot（--no-enable）")
    else:
        print(f"\n[2/2] 启用插件...")
        result = _enable_plugin(project_dir, ADDON_ENTRY)
        print(f"  {result}")

    _print_done()
    return 0


def _enable_plugin(project_dir: Path, plugin_entry: str) -> str:
    """在 project.godot 中启用指定插件。"""
    project_godot = project_dir / "project.godot"

    if not project_godot.is_file():
        return (f"警告: 找不到 project.godot，请在 Godot 编辑器中"
                f" 手动启用 {ADDON_NAME} 插件")

    with open(project_godot, "r", encoding="utf-8") as f:
        content = f.read()

    if plugin_entry in content:
        return "插件已处于启用状态，无需修改"

    new_content = _modify_project_godot(content, plugin_entry)

    with open(project_godot, "w", encoding="utf-8") as f:
        f.write(new_content)

    return f"已在 project.godot 中启用 {ADDON_NAME}"


def _modify_project_godot(content: str, plugin_entry: str) -> str:
    """修改 project.godot 的 [editor_plugins] 段，追加插件到 enabled 列表。"""
    lines = content.splitlines(keepends=True)

    # 找到 [editor_plugins] 段
    section_start: int = -1
    enabled_line: int = -1

    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "[editor_plugins]":
            section_start = i
        elif section_start >= 0 and stripped.startswith("enabled=PackedStringArray"):
            enabled_line = i
            break
        elif section_start >= 0 and stripped.startswith("[") and i > section_start:
            # 到了下一个段，[editor_plugins] 没有 enabled 行
            break

    entry_str = f'"{plugin_entry}"'

    if enabled_line >= 0:
        # 在现有列表中追加
        old_line = lines[enabled_line].rstrip("\n").rstrip("\r")
        # 分析括号内容
        m = re.match(r"(enabled=PackedStringArray\()(.+)(\))", old_line.strip())
        if m:
            prefix, inner, suffix = m.group(1), m.group(2), m.group(3)
            existing = [e.strip() for e in inner.split(",") if e.strip()]
            if not existing:
                # 空列表
                lines[enabled_line] = f"{prefix}{entry_str}{suffix}\n"
            else:
                # 追加
                lines[enabled_line] = f"{prefix}{inner}, {entry_str}{suffix}\n"
        else:
            # 格式异常，直接替换整行
            lines[enabled_line] = f'enabled=PackedStringArray({entry_str})\n'
    elif section_start >= 0:
        # [editor_plugins] 段存在但没有 enabled 行，在段头后插入
        lines.insert(section_start + 1, f'enabled=PackedStringArray({entry_str})\n')
    else:
        # [editor_plugins] 段不存在，追加到文件末尾
        if lines and not lines[-1].endswith("\n"):
            lines.append("\n")
        lines.append("\n")
        lines.append("[editor_plugins]\n")
        lines.append(f"enabled=PackedStringArray({entry_str})\n")

    return "".join(lines)


def _print_done() -> None:
    print()
    print("=== 完成！===")
    print(f"重启 Godot 编辑器后，在文件系统右键 → 新建 → ECS Component 即可使用。")

    print(f"""
提示：
  - 如果不需要编辑器工具，可以跳过此脚本，不影响框架运行时功能。
  - 若想禁用该插件，在 Godot 中打开：项目设置 → 插件 → 关闭 GF Editor Tools。
  - 重新运行本脚本可以更新到最新版的编辑器工具。
""")


if __name__ == "__main__":
    sys.exit(main())
