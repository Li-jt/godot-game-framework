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
│       ├── application/          # AppBootstrap、生命周期
│       ├── core/                 # ModuleLifecycle、OperationResult
│       ├── engine/               # 核心引擎适配层
│       ├── event/                # 事件总线
│       ├── logging/              # 日志服务
│       ├── runtime/              # 运行时模式
│       ├── modules/              # ← 可选模块
│       │   ├── ecs/              # ECS 世界
│       │   ├── input/            # 输入系统
│       │   ├── ui/               # UI 面板 + 拖拽
│       │   ├── save/             # 存档系统
│       │   ├── audio/            # 音频服务
│       │   ├── scene_host/       # 场景宿主
│       │   └── ...               # 更多可选模块
│       ├── scenes/               # 默认主场景
│       └── plugin.cfg            # 编辑器元信息
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

## 升级框架

### 更新到最新版本

```bash
# submodule 方式
cd addons/godot-game-framework
git checkout main
git pull origin main
cd ../..
git add addons/godot-game-framework
git commit -m "chore: 更新框架"

# 手动复制方式
# 重新下载最新 ZIP，覆盖 addons/godot-game-framework/
```

> **注意**：更新前请查看 [CHANGELOG](https://github.com/Li-jt/godot-game-framework/blob/main/CHANGELOG.md) 中的破坏性变更。

### v0.3 迁移指南

v0.3 是一次破坏性更新。如果你从 v0.2.x 升级，需要修改以下内容。

**1. Bootstrap API 变更**

```gdscript
# ❌ 旧（v0.2）
class_name MyGame
extends GF_AppBootstrap

func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    context.log.info("MyGame", "启动")
    context.ecs_scheduler.register_system(...)
    return GF_OperationResult.ok()

# ✅ 新（v0.3）
class_name MyGame
extends GF_AppBootstrap

func _assemble() -> void:
    register(GF_EcsWorld.new())
    register(GF_EcsScheduler.new())
    register(GF_SaveService.new())  # 不注册就不存在

func _on_ready() -> void:
    var log := service(GF_LogService) as GF_LogService
    log.info("MyGame", "启动")
    var sched := service(GF_EcsScheduler) as GF_EcsScheduler
    sched.register_system(...)
```

**2. 服务获取方式变更**

```gdscript
# ❌ 旧 — GF_GameServices context 对象
var log := context.log
var world := context.ecs_world

# ✅ 新 — class_name 引用直接获取
var log := service(GF_LogService) as GF_LogService
var world := service(GF_EcsWorld) as GF_EcsWorld
```

**3. 配置文件移除**

```gdscript
# ❌ 旧 — config/app_config.json 不存在了
# ✅ 新 — 代码默认值，在 _assemble() 中按需覆盖
func _assemble() -> void:
    var log := service(GF_LogService) as GF_LogService
    log.configure("Info", true, "user://my_logs")
```

**4. 删除的类**

以下类已被删除，需要用新方式替代：

| 旧类 | 替代 |
|------|------|
| `GF_GameServices` | `service(GF_XxxService)` |
| `GF_UiContext` | `_bootstrap.service(GF_XxxService)` |
| `GF_SaveContext` | `_bootstrap.service(GF_XxxService)` |
| `GF_GameplayContext` | `_bootstrap.service(GF_XxxService)` |
| `GF_ServiceRegistry` | `GF_AppBootstrap.register()/service()` |
| `GF_AppConfig` / `GF_AppConfigLoader` | 代码默认值 |
| `GF_UIPanel.ctx` | `GF_UIPanel._bootstrap` |

**5. SceneHost UI 节点树**

`default_main.tscn` 现在内置了完整的 UI 节点树。如果你有自己的主场景，建议参考 `default_main.tscn` 添加 SceneHost 节点及其层级。SceneHost 支持 `@export` 注入或自动创建默认树，详见 [UI 指南](../feature-guides/ui.md)。

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

### 安装

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
