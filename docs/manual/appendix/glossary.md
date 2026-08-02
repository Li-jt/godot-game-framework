# 术语表

本文档收录 godot-game-framework 框架中 36 个核心术语的精简定义。

---

## A

### AppBootstrap
应用启动装配器。使用 Installer 模式按阶段初始化所有框架服务，提供 10 个生命周期 Hook 供 Game 层注入自定义逻辑。位于 `application/app_bootstrap.gd`。

### AppFlow
应用流程状态机。管理 App 级的逻辑状态（BOOT / MAIN_MENU / LOADING / IN_GAME / PAUSE），状态切换通过 EventBus 通知所有模块。

### ActionDef
输入动作定义。描述一个游戏动作的 ID、默认按键绑定、手势配置等元数据。通过 `GF_InputService.register_action_def()` 注册。

### AudioBus
音频总线。Godot Audio Bus 的框架封装，提供音量调节、静音控制等操作。

---

## C

### Canvas Layer
Godot 内置的渲染层级。框架定义了 4 个标准 Canvas Layer：BACKGROUND（0）、WORLD（1）、UI（10）、SYSTEM（100），分别挂载背景、游戏世界、UI 面板、系统层（拖拽跟随/提示框）。

### class_name
GDScript 的全局类名注册关键字。本框架要求所有类通过 `class_name` 全局注册，禁止使用路径 `load()` / `preload()` 引用。

### CommandBus
命令总线。负责命令处理器（ICommandHandler）的注册和命令（ICommand）的分发执行。由 `GF_RuntimeService` 管理。

### CommandStrategy
命令执行策略抽象。不同运行时模式（LOCAL/REMOTE/HYBRID）下使用不同的策略实现。

### Context
窄上下文对象。`GF_GameplayContext`、`GF_UiContext`、`GF_SaveContext` 等，将完整的 `GF_GameServices` 按子系统拆分，避免 Game 层拿到不该访问的依赖。

---

## D

### DI (Dependency Injection)
依赖注入。框架通过 `configure()` 方法注入服务依赖，而非通过全局单例或 `_init()`。配置通过 `_on_post_boot()` 接收的 `GF_GameServices` 上下文传递。

### DebugService
调试服务。管理 FPS/帧时间统计、调试面板注册、命令追踪、网络统计。通过配置 `debug.enable_debug_panel` 启用。

---

## E

### ECS (Entity-Component-System)
实体-组件-系统架构模式。Entity 是 ID，Component 是纯数据，System 是纯逻辑。本框架的 ECS 基于 SparseSet 存储。

### Entity
ECS 中的实体。用一个整数 ID 表示，本身不包含数据。所有数据通过附加的 Component 描述。

### Component
ECS 中的组件。纯数据容器（Dictionary 或 GF_EcsComponentBase 子类），不持有 Node 引用。

### System
ECS 中的系统。纯逻辑计算单元，通过 `on_tick(world, ecb, delta)` 读取 World 并写入 ECB。系统之间通过 ECB 解耦。

### World
ECS 世界。管理所有实体和组件的生命周期，提供 spawn/despawn/add/get/set/remove/has 操作。

### ECB (EcsCommandBuffer)
ECS 命令缓冲区。System 不直接修改 World，而是向 ECB 写入命令，System 执行完毕后统一 apply 到 World。保证迭代安全。

### EventBus
事件总线。跨模块解耦通信机制。支持 publish/subscribe、scope 管理、一次性订阅、pending_removes 安全派发。

### EventToken
事件订阅令牌。subscribe 返回的 token，用于精确取消指定订阅。

---

## I

### ISaveable
可存档模块接口基类。实现 `save_key()` / `on_save()` / `on_load()` 方法的对象。支持鸭子类型（Node 和 RefCounted 子类均可实现）。

### InputContext
输入上下文。压入 GF_InputService 的上下文栈后，限制可用动作。支持 allowed_actions（白名单）、blocked_action_ids（黑名单）、block_all_game_actions（全禁）。

### InputBinding
输入按键绑定。描述一个动作到具体按键的映射。

### Installer
服务安装器。负责一个模块组的初始化、configure 和注册。框架有 Core/Engine/Ecs/Service 四个标准 Installer。

---

## L

### Lifecycle (ModuleLifecycle)
模块生命周期。所有服务继承 `GF_ModuleLifecycle`，状态机：UNINITIALIZED → INITIALIZING → INITIALIZED → CONFIGURING → READY。

### LogService
日志服务。分级日志输出（VERBOSE/DEBUG/INFO/WARNING/ERROR），替代 Godot 的 `print()` / `printerr()`。

---

## O

### OperationResult
统一操作结果类型。所有可能失败的方法返回此类型（不返回裸 bool 或 null）。包含 status_code（HTTP 风格）、success 标志、error（GF_ErrorInfo）、data（返回值）。

---

## P

### PathResolver
路径解析器。标准化资源路径，处理 `res://`、`user://` 前缀和路径拼接。

---

## R

### RebindService
按键重绑定服务。允许玩家自定义按键映射，持久化绑定配置。

### RuntimeMode
运行时模式。LOCAL（本地权威）、REMOTE（远程权威）、HYBRID（本地预测+远程确认）。当前仅 LOCAL 完整实现。

### ResourceService
资源服务。统一资源加载入口，提供缓存和 LRU 回收。

---

## S

### Scheduler
Tick 调度器。管理帧回调的注册和分组执行。按 TickGroup（PRE_FRAME/FRAME/POST_FRAME/PHYSICS/INTERVAL_*）组织回调顺序。

### SaveProvider
存档提供者接口。抽象存档的物理存储（本地文件、网络、数据库）。默认实现为 `GF_LocalSaveProvider`。

### SaveVersion
存档版本常量。每次修改存档数据结构时递增，配合 `GF_SaveVersionMigrator` 实现版本迁移。

### SceneFactory
场景工厂。统一场景/节点实例化入口，封装 PackedScene 加载与 instantiate()。位于 `engine/scene_factory/scene_factory.gd`。

### ServiceRegistry
服务注册中心。管理所有框架服务的注册、查询、优先级覆盖和按 owner 批量注销。

---

## T

### TickGroup
帧回调分组枚举。决定回调在每帧中的执行顺序和执行频率（每帧/每100ms/每500ms/每秒等）。

### ThreadingService
线程任务服务。管理后台任务的提交、调度、超时、重试和主线程回调回收。子线程任务必须是纯数据计算。

---

## U

### UIPanel
UI 面板基类。所有 UI 面板继承此类，通过 `GF_UIService` 管理生命周期。

### UIPanelDef
面板定义。描述面板的名称、场景路径、关闭策略（DESTROY_ON_CLOSE/HIDE_ON_CLOSE/PERSISTENT/MANAGED_BY_FLOW）、输入阻挡模式、Canvas Layer。

### UIDragHandler
拖拽处理器接口。游戏层继承此类实现自定义拖拽行为（on_begin_drag/on_drag/on_drop/on_end_drag）。

### UIDragManager
拖拽事件驱动 Node。管理拖拽状态机（空闲→拖拽中→放置/取消→空闲），协调 Handler 和 DropTarget。

---

## W

### WorldRoot
世界根节点。游戏世界场景的根节点基类，由 GF_AppBootstrap 注入 _bootstrap 引用，管理世界级 ISaveable 的自动扫描和增量注册。位于 `modules/world_root/world_root.gd`。
