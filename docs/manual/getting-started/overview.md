# 框架概览

## 框架解决什么问题

Godot 引擎提供了优秀的节点系统、场景系统和信号机制，但当项目规模增长时，以下几个痛点会逐渐浮现：

### 痛点 1：没有统一的依赖注入

Godot 的 `get_node()` 和 `$` 语法在小项目中很便捷，但当几十个脚本互相引用时，依赖关系变成蜘蛛网。Autoload 全局单例提供了"万能访问"，却隐藏了模块间的真实依赖，让测试和重构变得困难。

**框架方案**：每个服务通过 `configure()` 声明式接收依赖，调用的服务会通过 `GF_GameServices` 聚合对象显式传入。你一眼就能看出"这个类依赖哪些服务"。

### 痛点 2：没有统一的错误处理

一个项目中，有的函数返回 `bool` 表示成败、有的返回 `int`、有的返回 `null` 表示"没找到"。错误信息散落在 `print()` 和 `push_error()` 中，上层调用者无法程序化地判断"出了什么问题、我应该怎么处理"。

**框架方案**：所有可能失败的操作返回 `GF_OperationResult`，带有 HTTP 风格的状态码（200=成功，404=未找到，422=校验失败...），以及可追溯的错误链。

### 痛点 3：数据和行为混在场景树中

`Node` 既存数据（血量、位置）又存行为（移动逻辑、动画播放），导致：
- 存档时必须遍历整个场景树
- 单元测试必须挂载场景树（慢且脆弱）
- 数据和表现耦合，回放/快照难以实现

**框架方案**：ECS 架构将数据（Component）与行为（System）彻底分离。Component 是纯数据（Dictionary 或 RefCounted 对象），不持有 Node 引用。System 是无状态的纯逻辑，通过 Query 读取数据、通过 CommandBuffer 写回数据。

### 痛点 4：缺少标准的存档管线

自己实现存档通常面临：格式兼容性（更新后旧档崩溃）、数据收集（哪些数据需要存）、恢复顺序（地形恢复后才能放实体）、异步写入等问题。

**框架方案**：`GF_SaveService` 提供完整的存档管线——ISaveable 注册收集、版本迁移链、恢复优先级、槽位管理。

### 痛点 5：输入处理散落各处

`_input()` 和 `_unhandled_input()` 分散在多个脚本中，UI 面板打开时输入穿透到游戏、快捷键冲突等问题反复出现。

**框架方案**：`GF_InputService` 统一采集所有输入，设备归一化（键盘/手柄/触摸统一为 `InputRawSignal`），动作上下文栈控制"当前谁有权响应输入"。

### 痛点 6：UI 面板管理混乱

弹窗层叠、关闭逻辑不一致（有时 `hide()`，有时 `queue_free()`）、背景面板仍然可以交互——这些都是常见问题。

**框架方案**：`GF_UIService` 统一管理面板生命周期（DESTROY_ON_CLOSE / HIDE_ON_CLOSE / PERSISTENT / MANAGED_BY_FLOW）、输入阻挡策略、层级排序。

### 痛点 7：Mod 系统缺少标准挂载点

想支持 Mod，但不知道 Mod 应该在什么时候注册它的服务、注入它的 ECS 系统、添加它的输入映射。

**框架方案**：`GF_AppBootstrap` 提供 10 个生命周期 Hook（`_on_before_core_install`、`_on_after_ecs_install` 等），Mod 在明确的时机注入。

### 痛点 8：缺少 Tick 调度抽象

游戏逻辑直接写在 `_process(delta)` 里，当你要控制执行顺序（"物理先算，AI 后算，动画最后"）或节流（"AI 每 0.5 秒算一次"）时，需要手动写大量样板代码。

**框架方案**：`GF_Scheduler` 提供按组注册 tick 回调，支持优先级排序和帧频率控制。ECS 系统通过 `GF_EcsScheduler` 在三个标准分组中执行：Initialization → Simulation → Presentation。

## 不解决什么问题

框架**不是**渲染引擎、物理引擎、动画系统——这些 Godot 已经有优秀的实现。框架也**不提供**任何具体的游戏内容（角色、物品、关卡、技能）。它只提供能力和机制，不提供玩法和规则。

| 框架不负责 | 你应该用 |
|---|---|
| 渲染和视觉 | Godot 的 `Node2D`、`Sprite2D`、`Shader` |
| 物理和碰撞 | Godot 的 `CharacterBody2D`、`Area2D`、`PhysicsShape2D` |
| 动画和过渡 | Godot 的 `AnimationPlayer`、`Tween` |
| 瓦片地图 | Godot 的 `TileMap` |
| 游戏规则 | 你自己写的 ECS System |

## 核心设计原则

### GF_ 前缀

框架所有 `class_name` 以 `GF_` 前缀开头，与你的游戏类名清晰区分。当你看到 `GF_ModuleLifecycle`，你知道它来自框架；看到 `PlayerController`，你知道它来自游戏代码。

### class_name 全局引用

框架内所有类通过 `class_name` 全局注册，禁止使用 `load()` 或 `preload()` 加载框架类型。这意味着你写 `var world := GF_EcsWorld.new()` 而不是 `const World = preload("res://framework/ecs/ecs_world.gd")`。

### GF_OperationResult 统一返回

任何可能失败的操作必须返回 `GF_OperationResult`，不返回裸 `bool` 或 `null`。调用方必须检查 `is_ok()` / `is_fail()`，不允许静默吞错误。

### Game → Framework 单向依赖

你的游戏代码可以依赖框架的任何类型。框架代码绝不引用游戏层的类型。这个约束保证了框架的可复用性和可测试性。

### 接口通过基类 + 虚方法定义

GDScript 没有 `interface` 关键字。框架使用 `RefCounted` 基类 + 虚方法（子类必须覆写）来定义契约。接口类以 `I` 前缀命名（如 `GF_ISaveable`、`GF_IEcsWorld`）。

### 数据与表现分离

Node 树不是唯一真相源。ECS World 是运行时数据的权威存储。Component 是纯数据，不持有 Node 引用。System 通过 Query 读数据、通过 ECB 写数据。表现层（Sprite、动画）从 ECS 数据同步，而不是直接持有数据。

## 模块全景

| 模块 | 目录 | 一句话描述 |
|---|---|---|
| **Core** | `core/` | `GF_ModuleLifecycle`（服务生命周期）、`GF_OperationResult`（统一错误处理）、`GF_GameServices`（服务聚合）、`GF_ContentDefRegistry`（内容定义注册） |
| **ECS** | `ecs/` | `GF_EcsWorld`（实体与组件容器）、`GF_EcsSystem`（系统基类）、`GF_EcsQuery`（流式查询）、`GF_EcsCommandBuffer`（批量写入）、`GF_EcsScheduler`（系统调度） |
| **Engine** | `engine/` | `GF_SceneFactory`（场景工厂）、`GF_PathResolver`（路径标准化）、`GF_FileSystemService`（文件读写）、`GF_ThreadingService`（后台线程）、`GF_AssetLoadingService`（资源加载） |
| **Application** | `application/` | `GF_AppBootstrap`（启动装配）、`GF_ServiceRegistry`（服务注册中心）、Installer（分阶段安装器） |
| **Input** | `input/` | `GF_InputService`（输入采集与分发）、`GF_ActionContext`（动作上下文栈）、`GF_DeviceNormalizer`（设备归一化） |
| **UI** | `ui/` | `GF_UIService`（面板管理）、`GF_UIDragManager`（拖拽系统）、`GF_UIPanelDef`（面板定义） |
| **Save** | `save/` | `GF_SaveService`（存档读写）、`GF_SaveVersionMigrator`（版本迁移）、`GF_ISaveable`（可存档接口） |
| **Audio** | `audio/` | `GF_AudioService`（音频播放）、`GF_AudioCue`（音频事件） |
| **Resource** | `resource/` | `GF_ResourceService`（资源缓存）、LRU 回收策略 |
| **Event** | `event/` | `GF_EventBus`（跨模块事件通知） |
| **Flow** | `flow/` | `GF_AppFlow`（应用状态机：MainMenu / InGame / Loading） |
| **Logging** | `logging/` | `GF_LogService`（分级日志：debug / info / warn / error） |
| **Localization** | `localization/` | `GF_LocalizationService`（多语言文本查询） |
| **Debug** | `debug/` | `GF_DebugService`（性能统计、调试面板） |
| **Config** | `config/` | `GF_ConfigService`（游戏内容定义查询） |
| **Network** | `network/` | 网络请求抽象（Async HTTP） |
| **Data Access** | `data_access/` | Repository 接口（数据访问抽象） |

---

**下一步**: [快速开始](quick-start.md) — 动手写第一个 ECS 实体和系统，或 [项目结构](project-structure.md) 了解目录布局。
