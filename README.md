# Godot Game Framework (Godot 4.7)

分层架构 2D 游戏框架。所有类通过 `class_name` 全局注册，无需 `load()` 或路径导入。

## 版本

- **引擎要求**: Godot 4.7+
- **框架版本**: 0.3.0

## 分层

| 层 | 职责 |
|----|------|
| Application | 启动入口 `GF_AppBootstrap`，声明式服务装配 |
| Core | 通用基类、`ModuleLifecycle`、`OperationResult` |
| ECS | 实体组件系统（World/Query/CommandBuffer/Scheduler/Snapshot/Save）——代码组织工具 |
| Config | 配置加载、Def 校验 |
| Event | 事件总线 |
| Flow | 应用状态机 |
| Input | 输入服务、上下文栈、键位重绑定 |
| Logging | 日志服务 |
| UI | 面板管理、6 层 Canvas、拖拽系统、输入阻挡 |
| Audio | 音频服务 |
| Engine | Godot 适配层（调度、路径、场景、寻路） |
| Threading | 后台任务调度（优先级、取消、超时、重试、回调） |
| Resource | 资源缓存与加载 |
| Runtime | 运行时模式（Local/Remote/Hybrid）+ CommandBus |
| Save | 存档服务、版本迁移 |
| Network | 网络请求抽象 |
| DataAccess | Repository 接口 |
| Localization | 多语言本地化 |
| Debug | 调试统计 |

## 快速开始

### 安装

```bash
# 方式一：Git Submodule（推荐）
cd your-game
git submodule add https://github.com/Li-jt/godot-game-framework.git addons/godot-game-framework

# 方式二：直接复制
cp -r godot-game-framework addons/godot-game-framework
```

### 创建自己的 Bootstrap

```gdscript
# my_game.gd
class_name MyGame
extends GF_AppBootstrap

func _assemble() -> void:
    # 框架内置了 6 个基础服务（开箱即用）
    # Log、EventBus、PathResolver、Scheduler、FileSystem、RuntimeService

    # 按需注册你需要的模块 — 不注册就不存在
    register(GF_EcsWorld.new())
    register(GF_EcsScheduler.new())
    register(GF_SaveService.new())      # LocalSaveProvider 自动级联注册
    register(GF_InputService.new())      # InputAdapter 自动级联注册

    # 不想要 UI？不注册 GF_UIService 就行


func _on_ready() -> void:
    var log := service(GF_LogService) as GF_LogService
    log.info("MyGame", "启动完成")

    # 发送命令（Command 是一等公民）
    send_command(SpawnEntityCommand.new())
```

### 项目结构

```
your-game/
├── project.godot
├── src/
│   ├── application/    # 你的 Bootstrap 子类和业务入口
│   ├── game/           # 你的 Game 层（ECS 组件/系统/命令）
│   └── shared/
├── content/
│   ├── scenes/
│   ├── ui/
│   └── defs/
└── addons/
    └── godot-game-framework/  # ← 框架（来自本仓库）
```

### 启动

1. 安装框架到 `addons/godot-game-framework/`
2. 在 `project.godot` 中设置 `run/main_scene="res://addons/godot-game-framework/scenes/default_main.tscn"`
3. 点击运行 — 框架自带默认配置，开箱即用
4. 创建你自己的 `GF_AppBootstrap` 子类来构建游戏逻辑

### 编辑器工具（可选）

安装后可右键快速创建框架文件，详见 [安装指南](docs/manual/getting-started/installation.md#编辑器工具可选)。

## 核心 API

```gdscript
# 注册服务（自动识别单个实例或数组）
register(GF_SaveService.new())
register([GF_EcsWorld.new(), GF_EcsScheduler.new()])

# 获取服务（class_name 引用，类型安全）
var log := service(GF_LogService) as GF_LogService
var world := service(GF_EcsWorld) as GF_EcsWorld

# 发送命令
send_command(MyCommand.new())

# Service 统一写法
class_name MyService
extends GF_ModuleLifecycle

func dependencies() -> Array:
    return [GF_LogService, GF_PathResolver]

func configure() -> GF_OperationResult:
    var log: GF_LogService = _bootstrap.service(GF_LogService) as GF_LogService
    return GF_OperationResult.ok()
```

## 当前实现状态

### 已完成

- **声明式启动装配**：`_assemble()` 中按需 `register()`，依赖自动拓扑排序初始化
- **ECS 核心**：World、SparseSet/Archetype 双存储、Query、CommandBuffer、Scheduler、Snapshot、Save 适配
- **ECS 原生后端（Flecs/GDExtension）**：`GF_EcsWorld.new(StorageBackend.NATIVE)` 一键切换，
  API 面不变、GDScript 系统零迁移（对拍测试 45 用例验证）；探针实测查询路径
  12x-58x 收益。**预编译二进制随仓库分发，拉取即用**（Godot 4.7+，macOS
  universal 先行，其他平台按需补位）；编写 C++ 原生系统（§1.7）才需要
  本地编译链（见 gdextension/README.md）

## ECS 的定位：双后端策略

ECS 模块提供两个存储后端，使用方按规模选择：

- **GDScript 后端**（默认）：`SparseSet`/`Archetype` 存储。价值在**代码组织**——
  把游戏状态统一收进 World、把逻辑规整为 System、把变更约束到 CommandBuffer。
  零依赖、零编译，适用于实体量万级以下的项目；
- **原生后端**（opt-in）：Flecs + GDExtension（性能路线图 §1.6 第一步）。
  存储、查询、变更日志、快照全部下沉，`StorageBackend.NATIVE` 切换。
  适用于万级实体以上、tick 预算紧张的项目。

### 双后端对比

| 维度 | GDScript 后端 | 原生后端（Flecs） |
|------|--------------|-------------------|
| 组件数据 | `Dictionary` / `RefCounted`，存为 `Variant` | Flecs 列存储（当前列存 Variant，热字段 POD 列随 §1.7 交付） |
| 存储布局 | 每组件独立存储，Dictionary 查找 | Sparse set 列式，连续内存 |
| 查询路径 | GDScript 解释执行 + Variant 装箱 | 原生游标（实测 12x-58x，见性能路线图 §1.8） |
| 变更日志 | GDScript 组装 | Flecs observer 事件流 + 门面组装（语义对拍一致） |
| 部署 | 纯 GDScript，零依赖 | 本地 SConstruct 编译（godot-cpp submodule + Flecs amalgamated） |

### 后续升级路径

1. **原生系统执行环境**（§1.7，路线图排期）：热点 System 的 tick 循环整体下沉
   C++，预期 10x-100x
2. **并行系统调度**（§6.2，C++ 底座后）：按区域分块并行模拟

详见 [docs/manual/advanced/performance-optimization-roadmap.md](docs/manual/advanced/performance-optimization-roadmap.md)。
- **ThreadingService**：后台任务提交与主线程回收（优先级、取消、超时、重试）
- **InputService v4.0**：Action 归一化、上下文栈、键位重绑定、录制回放
- **SaveService**：ISaveable 自注册、多槽位、版本迁移链、恢复优先级、原子写入
- **UI**：面板管理（6 层 Canvas 自动创建）、拖拽系统、输入阻挡策略
- **寻路框架**：IPathGraph + ITraversal + IHeuristic 三层可插拔 A\*
- **AudioService**：Cue 播放、Bus 分组、SFX 池化
- **Command 一等公民**：`send_command()` 直接挂载在 Bootstrap 上

### 尚未完整

- Runtime 的 Remote/Hybrid 策略为预留，当前以 Local 为主
- Network 层为抽象基类 + Mock 客户端，尚无真实 HTTP/WebSocket 实现
- DataAccess 以 Repository 接口为主，缺少完整 Provider 闭环

## 升级框架

```bash
cd addons/godot-game-framework
git pull origin main
```

注意 `CHANGELOG.md` 中的破坏性变更。

## 文档

完整用户手册请参阅 [`docs/manual/`](docs/manual/)：

| 章节 | 内容 |
|------|------|
| [快速开始](docs/manual/getting-started/quick-start.md) | 第一个框架项目 |
| [安装指南](docs/manual/getting-started/installation.md) | 安装、编辑器工具、验证 |
| [项目结构](docs/manual/getting-started/project-structure.md) | 推荐目录组织 |
| [核心概念](docs/manual/core-concepts/) | ECS World、ModuleLifecycle、OperationResult 等 |
| [功能指南](docs/manual/feature-guides/) | 输入、UI、存档、音频、场景切换等 |
| [最佳实践](docs/manual/best-practices/) | 性能指南、常见陷阱、Cookbook |
| [进阶](docs/manual/advanced/) | 自定义 Saveable、快照回放、线程计算等 |
| [API 参考](docs/manual/api-reference/) | 所有类的接口文档 |
| [排错](docs/manual/troubleshooting/) | 常见问题、诊断工具、错误码 |
| [附录](docs/manual/appendix/) | 术语表、class_name 索引、迁移指南、FAQ |

## 设计原则

- **Framework 只负责能力和机制，不负责玩法和规则** — 不含任何具体游戏业务名词
- **Game → Framework 单向依赖** — Framework 绝不引用 Game 层类型
- **所有类通过 `class_name` 全局引用** — 不写路径 `load()` / `preload()`
- **所有公共 API 返回 `OperationResult`** — 不返回裸 `bool` 或 `null`
- **ECS 组件是纯数据** — 不持有 Node 引用
- **系统通过 CommandBuffer 写入 World** — 不直接修改存储
- **服务注册使用 class_name 引用，禁止字符串 key** — `service(GF_LogService)` 不是 `service("Log")`

详见 [CLAUDE.md](CLAUDE.md)。
