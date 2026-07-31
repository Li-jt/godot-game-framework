# 安装指南

## 方式一：Git Submodule（推荐）

Git Submodule 可以精确控制框架版本，同时方便同步更新。

```bash
# 在游戏项目根目录
cd your-game

# 添加 framework 为 submodule
git submodule add https://github.com/your-org/godot-game-framework.git src/framework

# 提交 .gitmodules 和 submodule 引用
git commit -m "chore: 添加 godot-game-framework 作为 submodule"
```

**更新框架**：

```bash
cd src/framework
git checkout main
git pull origin main

# 回到游戏项目，提交 submodule 指针更新
cd ../..
git add src/framework
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

如果你的项目不使用 Git，或者你希望完全拥有副本：

1. 从 GitHub 下载框架的最新 ZIP 包。
2. 解压到游戏项目的 `src/framework/` 目录下。
3. 确保目录结构与原仓库一致（所有 `class_name` 依赖文件组织不变）。

```text
your-game/
└── src/
    └── framework/
        ├── application/
        ├── core/
        ├── ecs/
        ├── engine/
        ├── environment/
        ├── event/
        ├── flow/
        ├── input/
        ├── ui/
        ├── save/
        ├── ...
        └── plugin.cfg          # 确保此文件存在
```

## 目录结构要求

框架代码必须完整放置在 `src/framework/` 下，内部目录结构不能改变：

```text
your-game/
├── project.godot
├── src/
│   └── framework/              # ← 框架代码根目录
│       ├── application/        # AppBootstrap, ServiceRegistry
│       ├── core/               # ModuleLifecycle, OperationResult
│       ├── ecs/                # ECS 完整实现
│       ├── engine/             # 引擎适配层
│       ├── input/              # 输入服务
│       ├── ui/                 # UI 服务
│       ├── save/               # 存档服务
│       ├── audio/              # 音频服务
│       ├── logging/            # 日志服务
│       ├── event/              # 事件总线
│       ├── flow/               # 应用流程
│       ├── resource/           # 资源服务
│       ├── config/             # 配置服务
│       ├── localization/       # 本地化
│       ├── debug/              # 调试服务
│       ├── network/            # 网络抽象
│       ├── data_access/        # 数据访问
│       ├── environment/        # AppConfig 加载
│       ├── runtime/            # 运行时模式
│       ├── docs/               # 框架文档（可选保留）
│       └── plugin.cfg          # 插件描述文件
```

**为什么目录结构不能改**：框架所有类型通过 `class_name` 全局注册，Godot 在启动时扫描所有 `.gd` 文件来解析 `class_name`。只要文件在 `res://` 下，Godot 就能找到。但框架内部的 `plugin.cfg` 也会被 Godot 扫描，我们用它来声明框架为插件。

## project.godot 配置

### 1. 启用框架插件

在 Godot 编辑器中：**项目 → 项目设置 → 插件**，勾选 **Godot Game Framework**。

或者直接编辑 `project.godot`：

```ini
[editor_plugins]
enabled=PackedStringArray("res://src/framework/plugin.cfg")
```

`plugin.cfg` 的内容：

```ini
[plugin]
name="Godot Game Framework"
description="2D Game Framework with ECS, DI, and unified error handling"
author="Your Name"
version="1.0.0"
script="application/app_bootstrap.gd"
```

### 2. 配置主场景

在 `project.godot` 中指定你的主场景（根节点挂载了你的 `MyGameBootstrap` 脚本）：

```ini
[application]
run/main_scene="res://scenes/main.tscn"
```

### 3. Autoload 说明

框架**不需要**任何 Autoload。所有服务由 `GF_AppBootstrap` 在启动时创建并注入。你的游戏代码通过 `GF_GameServices` 聚合对象获取服务引用，而不是通过全局 Autoload。

如果你有自己的全局服务（极少情况），可以在 Autoload 中注册，但它们不应依赖框架服务（因为框架服务在 Autoload 之后才初始化）。

## 验证安装

创建以下测试场景确认框架安装成功：

1. 创建一个场景，根节点挂载以下脚本：

```gdscript
# scenes/test_bootstrap.gd
extends Node


func _ready() -> void:
    # 验证核心类是否可用（class_name 已全局注册）
    var result := GF_OperationResult.ok({"hello": "world"})
    if result.is_ok():
        print("框架安装成功！")
        print("数据: ", result.data)
    else:
        printerr("框架安装失败")

    # 验证 ECS World 是否可用
    var world := GF_EcsWorld.new()
    var entity := world.spawn()
    world.set_component(entity, &"Test", {"value": 42})
    var data = world.get_component(entity, &"Test")
    print("实体 %d 的 Test 组件: %s" % [entity, data])
```

2. 运行这个场景。如果控制台输出了"框架安装成功"和组件数据，说明框架可用。

### 常见安装问题

| 问题 | 原因 | 解决 |
|---|---|---|
| `GF_OperationResult` 未定义 | Godot 未扫描到框架的 `.gd` 文件 | 确认 `src/framework/` 目录完整且文件存在 |
| 插件未出现在列表中 | `plugin.cfg` 路径不对 | 确认 `plugin.cfg` 在 `src/framework/plugin.cfg` |
| 编辑器报脚本错误 | Godot 版本低于 4.7 | 升级 Godot 到 4.7+ |
| `class_name` 冲突 | 你的游戏定义了与框架同名的 `class_name` | 框架类都用 `GF_` 前缀，避免在你的代码中使用 `GF_` 前缀 |

## 编辑器工具（可选）

框架附带了一个编辑器工具 addon，安装后可以在 FileSystem 面板中**右键 → 新建**，快速创建 8 种常用框架文件，无需手写样板代码。

### 一键安装

框架代码中已包含安装脚本，双击运行即可：

| 平台 | 操作 |
|------|------|
| **macOS** | 在 Finder 中双击 `src/framework/scripts/mac/setup_editor_tools.command` |
| **Windows** | 在资源管理器中双击 `src\framework\scripts\win\setup_editor_tools.bat` |

脚本会自动完成以下操作：

1. 向上搜索 `project.godot` 定位你的游戏项目根目录
2. 将框架的 `addons/gf_editor_tools/` 复制到项目的 `addons/gf_editor_tools/`
3. 在 `project.godot` 中启用 **GF Editor Tools** 插件

不用担心重复运行——脚本会检测已有安装，仅在你确认后才覆盖。

### 手动安装

如果脚本不适用，也可以手动操作：

```bash
# 1. 复制 addon
cp -r src/framework/addons/gf_editor_tools addons/gf_editor_tools

# 2. 启用插件 —— 在 Godot 编辑器中打开：
#    项目 → 项目设置 → 插件 → 勾选 "GF Editor Tools"
```

### 使用

重启 Godot 编辑器后，在 **FileSystem** 面板中**右键 → 新建**，在"文件夹/脚本/场景/资源"下方可看到两个分组子菜单：

```
右键 → 新建 → ECS  →  Component
                   →  System
                   →  Command
            → Game →  UI Panel
                    →  Module Service
                    →  Saveable Module
                    →  World Root
                    →  App Bootstrap
```

选择对应菜单项后，在弹出的对话框中输入名称，即可生成包含基类必须覆写的所有方法桩代码、类型声明和文档注释的 `.gd` 文件。

#### ECS 组

这三个菜单项覆盖了 ECS 架构的三种核心文件类型。

**ECS → Component** — 实体组件（纯数据）

> 继承 `GF_EcsComponentBase`。组件是挂载在实体上的纯数据包，不持有 Node 引用。

输入 `health`，生成 `health_component.gd`：

```gdscript
## HealthComponent 组件数据。
class_name HealthComponent
extends GF_EcsComponentBase


const TYPE: StringName = &"HealthComponent"


func get_component_type() -> StringName:
    return TYPE


func serialize() -> Dictionary:
    return {}


func deserialize(p_data: Dictionary) -> void:
    pass
```

使用方式：`world.add_component(entity, HealthComponent.TYPE, {"hp": 100})`

**ECS → System** — 系统逻辑（每帧执行）

> 继承 `GF_EcsSystem`。系统在每帧（或按 tick_interval 间隔）被调度执行，通过 ECB（EcsCommandBuffer）读写 World。

输入 `movement`，生成 `movement_system.gd`：

```gdscript
## MovementSystem 系统逻辑。
class_name MovementSystem
extends GF_EcsSystem


func on_init(p_world: GF_EcsWorld) -> void:
    pass


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    pass


func on_shutdown() -> void:
    pass
```

使用时在 `AppBootstrap._on_post_boot()` 中注册到 Scheduler。

**ECS → Command** — 游戏命令

> 继承 `GF_ICommand`。命令封装一次游戏操作（建造、攻击、交易等），支持前置验证和可撤销。

输入 `place_building`，生成 `place_building_command.gd`：

```gdscript
## PlaceBuildingCommand 命令。
class_name PlaceBuildingCommand
extends GF_ICommand


func command_key() -> String:
    return "place_building"


func execute(_p_context: Dictionary) -> GF_OperationResult:
    return GF_OperationResult.ok()


func validate(_p_context: Dictionary) -> GF_OperationResult:
    return GF_OperationResult.ok()
```

使用时通过 `CommandBus.execute(PlaceBuildingCommand.new(), context)` 调用。

---

#### Game 组

这五个菜单项覆盖了游戏层最常创建的模块类型。

**Game → UI Panel** — UI 面板

> 继承 `GF_UIPanel`。管理面板的打开/关闭/隐藏生命周期。策略（DESTROY/HIDE/PERSISTENT）由 `UIPanelDef` 配置。

输入 `inventory`，生成 `inventory_panel.gd`：

```gdscript
## InventoryPanel UI 面板。
class_name InventoryPanel
extends GF_UIPanel


func _on_open(_p_data: Dictionary) -> void:
    pass


func _on_close() -> void:
    pass


func _on_hide() -> void:
    pass


func _on_reopen(_p_data: Dictionary) -> void:
    pass
```

**Game → Module Service** — 自定义服务模块

> 继承 `GF_ModuleLifecycle`。所有框架服务都继承此类。管理 `UNINITIALIZED → INITIALIZING → INITIALIZED → CONFIGURING → READY` 生命周期状态机。

输入 `trade`，生成 `trade_service.gd`：

```gdscript
## TradeService 模块服务。
class_name TradeService
extends GF_ModuleLifecycle


func _on_init() -> GF_OperationResult:
    return GF_OperationResult.ok()


func _on_dispose() -> GF_OperationResult:
    return GF_OperationResult.ok()
```

**Game → Saveable Module** — 可存档模块

> 继承 `GF_ISaveable`。实现 `save_key()`/`on_save()`/`on_load()` 接口。注册到 `SaveService` 后，存读档时自动收集和恢复数据。

输入 `inventory`，生成 `inventory_saveable.gd`：

```gdscript
## InventorySaveable 存档模块。
class_name InventorySaveable
extends GF_ISaveable


func save_key() -> String:
    return "inventory"


func on_save() -> Dictionary:
    return {}


func on_load(p_data: Dictionary) -> void:
    pass
```

**Game → World Root** — 世界场景根节点

> 继承 `GF_WorldRoot`。每个游戏世界场景（关卡、地图）的根节点应继承此类。SceneHost 加载世界后自动注入 `ctx: GF_GameServices`，然后调用 `_on_world_setup()`。

输入 `dungeon`，生成 `dungeon_world.gd`：

```gdscript
## DungeonWorld 世界根节点。
class_name DungeonWorld
extends GF_WorldRoot


func _on_world_setup() -> void:
    pass


func _on_world_exit() -> void:
    pass
```

**Game → App Bootstrap** — 应用启动引导

> 继承 `GF_AppBootstrap`。每个项目只需一个。挂载在主场景根节点上，提供 10 个生命周期钩子（分阶段安装 Core/Engine/ECS/Service）。在 `_on_post_boot()` 中注册 ECS 系统和游戏服务。

输入 `my_game`，生成 `my_game_bootstrap.gd`：

```gdscript
## MyGameBootstrap 应用启动引导。
class_name MyGameBootstrap
extends GF_AppBootstrap


func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    return GF_OperationResult.ok()


func _on_app_ready(p_context: GF_GameServices) -> void:
    pass
```

### 后续更新

框架更新后，重新运行安装脚本即可同步最新的编辑器工具。**如果不使用编辑器工具，完全可以跳过本节**——不影响框架的任何运行时功能。

### 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| "找不到 project.godot" | 脚本不在框架目录下运行，或框架不在游戏项目子目录中 | 确认框架放在 `src/framework/` 下，脚本在 `src/framework/scripts/` 内 |
| "找不到 addons/gf_editor_tools" | 框架目录结构不完整 | 确认拉取了完整的框架代码，包含 `addons/` 目录 |
| 右键菜单没有模板列表 | 插件未启用 | 检查 项目设置 → 插件 → GF Editor Tools 是否勾选 |
| 创建的文件无法识别基类 | Godot 未加载框架脚本 | 重启编辑器，确保框架的 `.gd` 文件已被扫描 |
| 不影响打包体积吗？ | — | 不影响。`.gd` 文件是文本，且导出时依赖编辑器类型的脚本不会被包含 |

---

**下一步**: [项目结构](project-structure.md) — 了解推荐的目录组织，或 [快速开始](quick-start.md) 动手写代码。
