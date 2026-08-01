# 安装指南

## 方式一：Git Submodule（推荐）

```bash
# 在游戏项目根目录
cd your-game

# 如果项目还不是 Git 仓库，先初始化
git init

# 添加 framework 为 submodule
git submodule add https://github.com/Li-jt/godot-game-framework.git addons/godot-game-framework

# 提交 .gitmodules 和 submodule 引用
git commit -m "chore: 添加 godot-game-framework 作为 submodule"
```

**更新框架**：

```bash
cd addons/godot-game-framework
git checkout main
git pull origin main

# 回到游戏项目，提交 submodule 指针更新
cd ../..
git add addons/godot-game-framework
git commit -m "chore: 更新 framework 到最新版本"
```

**克隆含 submodule 的项目**：

```bash
git clone --recurse-submodules <your-game-repo-url>
# 或者先 clone 再初始化 submodule
git clone <your-game-repo-url>
cd your-game
git submodule update --init --recursive
```

## 方式二：手动复制

1. 从 GitHub 下载框架的最新 ZIP 包。
2. 解压到游戏项目的 `addons/godot-game-framework/` 目录下。

## 方式三：Asset Library（即将支持）

框架将发布到 Godot Asset Library，届时可以在 Godot 编辑器内 **AssetLib** 面板搜索安装。

---

## 启动框架

安装完成后，在 `project.godot` 中设置框架自带的默认主场景：

```ini
[application]
run/main_scene="res://addons/godot-game-framework/scenes/default_main.tscn"
```

点击运行。控制台输出 "Godot Game Framework 就绪！" 表示安装成功。

**不需要创建配置文件、不需要写代码、不需要启用插件。** 框架使用 `class_name` 全局注册，放在 `addons/` 下即可被 Godot 自动扫描。

---

## 目录结构

安装后的项目结构：

```text
your-game/
├── project.godot
├── addons/
│   └── godot-game-framework/    # ← 框架（不可修改）
│       ├── application/          # AppBootstrap, ServiceRegistry
│       ├── core/                 # ModuleLifecycle, OperationResult
│       ├── ecs/                  # ECS 完整实现
│       ├── engine/               # 引擎适配层
│       ├── input/                # 输入服务
│       ├── ui/                   # UI 服务
│       ├── save/                 # 存档服务
│       ├── audio/                # 音频服务
│       ├── logging/              # 日志服务
│       ├── event/                # 事件总线
│       ├── flow/                 # 应用流程
│       ├── resource/             # 资源服务
│       ├── config/               # 配置服务
│       ├── localization/         # 本地化
│       ├── debug/                # 调试服务
│       ├── network/              # 网络抽象
│       ├── data_access/          # 数据访问
│       ├── environment/          # AppConfig 加载
│       ├── runtime/              # 运行时模式
│       ├── scenes/               # 默认主场景
│       ├── default_app_config.json  # 框架默认配置
│       └── plugin.cfg            # 编辑器元信息
├── config/                       # （可选）覆盖默认配置
│   └── app_config.json
├── content/                      # 游戏资源
└── scenes/                       # 你的主场景
```

**为什么目录结构不能改**：框架所有类型通过 `class_name` 全局注册，Godot 在启动时扫描所有 `.gd` 文件来解析 `class_name`。只要文件在 `res://` 下，Godot 就能找到。无需额外配置。

---

## project.godot 配置

### 配置主场景

框架提供默认主场景 `res://addons/godot-game-framework/scenes/default_main.tscn`，直接运行即可。

当你创建了自己的 Bootstrap 后，改为指向你的主场景：

```ini
[application]
run/main_scene="res://scenes/main.tscn"
```

### Autoload 说明

框架**不需要**任何 Autoload。所有服务由 `GF_AppBootstrap` 在启动时创建并注入。

---

## 自定义配置（可选）

框架自带默认配置，开箱即用。如需覆盖，在项目根目录创建 `config/app_config.json`，只写你要改的字段：

```json
{
  "app": {
    "name": "My Awesome Game",
    "version": "1.0.0"
  },
  "logging": {
    "level": "Info"
  }
}
```

完整配置项参见[配置参考](../core-concepts/configuration.md)。

---

### 常见问题

| 问题 | 原因 | 解决 |
|---|---|---|
| `GF_OperationResult` 未定义 | Godot 未扫描到框架的 `.gd` 文件 | 确认 `addons/godot-game-framework/` 目录完整且文件存在 |
| 编辑器报脚本错误 | Godot 版本低于 4.7 | 升级 Godot 到 4.7+ |
| `class_name` 冲突 | 你的游戏定义了与框架同名的 `class_name` | 框架类都用 `GF_` 前缀，避免在你的代码中使用 `GF_` 前缀 |

---

## 编辑器工具（可选）

框架附带了一个编辑器工具 addon，安装后可以在 FileSystem 面板中**右键 → 新建**，快速创建 8 种常用框架文件模板。

### 一键安装

| 平台 | 操作 |
|------|------|
| **macOS** | 在 Finder 中双击 `addons/godot-game-framework/scripts/mac/setup_editor_tools.command` |
| **Windows** | 在资源管理器中双击 `addons\godot-game-framework\scripts\win\setup_editor_tools.bat` |

### 手动安装

```bash
cp -r addons/godot-game-framework/addons/gf_editor_tools addons/gf_editor_tools
```

然后在 Godot 编辑器中：**项目 → 项目设置 → 插件 → 勾选 "GF Editor Tools"**。

### 使用

重启 Godot 编辑器后，在 FileSystem 面板中**右键 → 新建**，在菜单中可看到 **ECS** 和 **Game** 两组模板：

- **ECS** → Component / System / Command
- **Game** → UI Panel / Module Service / Saveable Module / World Root / App Bootstrap

选择对应菜单项后输入名称即可生成 `.gd` 文件。

---

**下一步**: [快速开始](quick-start.md) — 运行框架，或 [项目结构](project-structure.md) — 了解推荐目录组织。
