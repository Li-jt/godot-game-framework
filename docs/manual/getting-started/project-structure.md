# 项目结构

## 框架内部目录树

框架代码分为两个层级：**核心**（Core，项目启动即自动加载）和**可选模块**（Modules，用户按需 `register()`）。

```text
framework/
├── plugin.cfg                          # 插件描述文件
├── application/                        # 核心：启动与装配
│   └── app_bootstrap.gd                # GF_AppBootstrap — 启动基类
├── core/                               # 核心：基础抽象（不依赖场景树）
│   ├── module_lifecycle.gd             # GF_ModuleLifecycle — 服务生命周期
│   ├── operation_result.gd             # GF_OperationResult — 统一操作结果
│   ├── error_info.gd                   # GF_ErrorInfo — 错误信息结构
│   ├── content_def_registry.gd         # GF_ContentDefRegistry — 内容定义注册表
│   ├── def_id_registry.gd              # GF_DefIdRegistry — ID 注册表
│   ├── def_json_loader.gd              # GF_DefJsonLoader — JSON 加载工具
│   └── object_pool.gd                  # GF_ObjectPool — 通用对象池
├── engine/                             # 核心：Godot 引擎适配层
│   ├── scheduler/                      # GF_Scheduler — Tick 调度
│   ├── path_resolver/                  # GF_PathResolver — 路径标准化
│   ├── file_system/                    # GF_FileSystemService — 文件读写
│   └── scene_factory/                  # GF_SceneFactory — 场景实例化
├── event/                              # 核心：EventBus
│   └── event_bus.gd                    # GF_EventBus
├── logging/                            # 核心：日志服务
│   └── log_service.gd                  # GF_LogService
├── runtime/                            # 核心：运行时
│   ├── command_bus.gd                  # GF_CommandBus — 命令总线
│   ├── i_command.gd                    # GF_ICommand — 命令接口
│   └── ...
├── modules/                            # 可选模块（用户按需 register）
│   ├── ecs/                            # ECS 数据架构
│   ├── input/                          # 输入处理
│   ├── input_adapter/                  # 输入适配器
│   ├── ui/                             # UI 面板管理 + 拖拽（自包含，启动时创建节点树）
│   ├── world_root/                     # GF_WorldRoot — 世界场景基类
│   ├── save/                           # 存档管线
│   ├── audio/                          # 音频服务
│   ├── audio_runtime/                  # 音频底层播放
│   ├── resource/                       # 资源管理
│   ├── asset_loading/                  # 资源加载
│   ├── config/                         # 内容配置
│   ├── network/                        # 网络抽象
│   ├── data_access/                    # 数据访问接口
│   ├── flow/                           # 应用状态机
│   ├── localization/                   # 本地化
│   ├── debug/                          # 调试服务
│   ├── threading/                      # 多线程服务
│   ├── runtime_utilities/              # 运行时工具（NodePool等）
│   └── algorithm/                      # A* 寻路
└── scenes/                             # 场景模板
    ├── default_main.tscn               # 默认主场景
    └── default_bootstrap.gd            # 默认 Bootstrap
```

## 使用者推荐目录树

以下是推荐的游戏项目目录结构。游戏代码放在 `src/game/` 下，框架放在 `addons/godot-game-framework/` 下，二者物理分离。

```text
your-game/
├── project.godot                       # Godot 项目文件
├── .gitignore
├── .gitmodules                         # submodule 引用（如果用 submodule）
│
├── config/                             # （可选）覆盖默认配置
│   └── app_config.json
│
├── addons/
│   └── godot-game-framework/           # 框架代码（submodule 或复制）
│       └── ...                         # 内部目录结构不变
│
├── content/                            # 游戏资产（非代码）
│   ├── scenes/                         # .tscn 场景文件
│   │   ├── main.tscn                   # 主场景（挂载 MyGameBootstrap）
│   │   ├── worlds/                     # 游戏世界场景
│   │   └── actors/                     # 角色实例场景
│   ├── ui/                             # UI 面板场景
│   │   ├── main_hud.tscn
│   │   ├── inventory_panel.tscn
│   │   └── dialog_panel.tscn
│   ├── defs/                           # 游戏内容定义（JSON）
│   │   ├── items.json
│   │   ├── buildings.json
│   │   └── recipes.json
│   ├── textures/                       # 贴图
│   ├── audio/                          # 音频
│   └── fonts/                          # 字体
│
├── src/
│   ├── application/                    # 应用层
│   │   └── my_game_bootstrap.gd        # 你的 AppBootstrap 子类
│   │
│   ├── game/                           # 游戏层（你自己的代码）
│   │   ├── components/                 # ECS 组件定义
│   │   │   ├── position.gd
│   │   │   ├── velocity.gd
│   │   │   └── health.gd
│   │   ├── systems/                    # ECS 系统实现
│   │   │   ├── movement_system.gd
│   │   │   ├── health_system.gd
│   │   │   └── ai_system.gd
│   │   ├── commands/                   # 游戏命令（建造、攻击等）
│   │   │   ├── move_command.gd
│   │   │   └── attack_command.gd
│   │   ├── ui/                         # 游戏特有的 UI 脚本
│   │   │   ├── hud_controller.gd
│   │   │   └── inventory_controller.gd
│   │   └── save/                       # 存档适配（如有自定义存档逻辑）
│   │       └── game_saveable.gd
│   │
│   └── shared/                         # 游戏内共享常量和工具
│       ├── game_constants.gd
│       └── game_utils.gd
│
└── tests/                              # 测试
    ├── unit/
    │   ├── components/
    │   └── systems/
    └── integration/
```

## 各目录职责说明

### `config/`（可选）

框架自带默认配置，`config/` 目录仅在需要覆盖默认值时创建。`app_config.json` 定义游戏名、版本、日志级别、运行模式等，只需写要覆盖的字段。详见[配置文件](configuration.md)。

### `content/`

存放所有游戏资产——场景、贴图、音频、字体、以及 JSON 格式的游戏内容定义（物品、建筑、配方等）。资产文件不包含代码逻辑。`defs/` 下的 JSON 文件通过 `GF_ContentDefRegistry` 加载和查询。

### `addons/godot-game-framework/`

框架代码。你不应该修改这里的任何文件。更新时替换整个目录即可。

### `src/application/`

你的应用层代码。核心文件是继承 `GF_AppBootstrap` 的启动类，在这里：
- 注册 ECS 组件类型
- 注册 ECS 系统和命令处理器
- 在生命周期 Hook 中注入游戏特有的服务

### `src/game/`

游戏逻辑的**全部**代码。按功能域分子目录：

| 子目录 | 内容 |
|---|---|
| `components/` | ECS 组件类（继承 `GF_EcsComponentBase` 的纯数据对象） |
| `systems/` | ECS 系统类（继承 `GF_EcsSystem`，`on_tick()` 中实现逻辑） |
| `commands/` | 命令定义和处理器（继承 `GF_ICommand`） |
| `ui/` | 游戏特有的 UI 面板脚本 |
| `save/` | 实现 `GF_ISaveable` 的数据对象 |

### `src/shared/`

游戏内跨模块共享的常量和工具函数。不依赖框架，也不被框架依赖。

### `tests/`

测试文件。按照被测模块的路径镜像组织。详见 `docs/testing_strategy.md`。

## 关键原则

1. **框架代码不修改**：`addons/godot-game-framework/` 是第三方代码，更新时直接替换整个目录。
2. **游戏代码在 `game/` 下**：所有你自己写的逻辑放在 `src/game/`，与框架物理分离。
3. **资产在 `content/` 下**：贴图、音频、场景文件等不包含代码逻辑。
4. **配置在 `config/` 下**：JSON 配置文件，运行时加载，不编译。
5. **Game → Framework 单向依赖**：你的代码引用框架类型（`GF_EcsWorld`），框架绝不引用你的类型。

---

**下一步**: [配置文件](configuration.md) — 了解 `app_config.json` 的所有字段和校验规则，或返回[快速开始](quick-start.md)。
