# 常见疑问 (FAQ)

---

## 这个框架和直接用 Godot 有什么区别？

直接用 Godot 开发游戏时，你需要自己处理以下基础设施：

- 服务生命周期管理（初始化顺序、依赖注入、销毁）
- ECS 架构的自行实现
- 输入系统的上下文管理和按键绑定
- UI 面板开/关管理和拖拽系统
- 存档系统的序列化、版本迁移
- 事件总线
- 线程任务调度
- 应用流程状态机

godot-game-framework 提供了这些通用基础设施的现成实现，让你专注于游戏玩法逻辑。框架不包含任何具体游戏业务代码。

---

## 是否适合小型项目？

取决于需求：

- **适合**: 中型及以上的项目，或者即使项目较小但你希望有清晰的分层架构和可维护的代码基础
- **不太适合**: Game Jam 级别的极简项目、或不打算长期维护的一次性项目

框架有一定学习曲线，但带来的架构收益在项目中后期会体现出来。

---

## ECS 性能如何？能支持多少实体？

框架提供了两种存储实现：

- **SparseSet**：适合组件组合多变的场景，10,000-50,000 实体级别
- **Archetype**：适合组件组合固定的批量查询，性能更高

实际性能取决于：
- 实体数量和组件数量
- System 数量和查询复杂度
- 每帧的 mutation 频率（spawn/despawn/add/remove）

建议在目标硬件上进行性能基准测试。

---

## 为什么不用直接用 Godot 的 Node 做组件？

Godot 的 Node 树是一个优秀的场景组织机制，但有几点限制：

1. **Node 开销大**：每个 Node 拥有信号、transform、process 等全套能力，即使只需要存两个 float
2. **查询不高效**：通过 `get_node()` 或 `find_child()` 查询特定组件组合，在大规模场景下效率低
3. **序列化不灵活**：Node 的序列化依赖 `.tscn` 格式，不适合自定义存档
4. **不适合纯逻辑实体**：很多实体是逻辑概念（如 AI 状态机中的一个决策节点），不需要视觉表现

ECS 方案将"纯数据组件"与"视觉表现"分离，提供更高效的数据查询和更灵活的序列化。

**但在合适的地方仍然使用 Node**：视觉对象、物理体、UI 控件仍然通过标准的 Godot Node 管理。

---

## 框架是否可以用于 3D 游戏？

可以。框架的架构层（Core、ECS、EventBus、Save、Application 等）与维度无关。

需要注意的适配点：
- Canvas Layer 分层概念是 2D 的，3D UI 可能需要额外的适配
- 部分 Engine 层的工具（如 Pathfinder）目前是 2D 实现

3D 项目的关键适配工作集中在 Engine 层和视觉层。

---

## class_name 全局注册会不会冲突？

框架的所有 `class_name` 使用 `GF_` 前缀（Godot Framework），降低了与 Game 层命名冲突的可能性。

建议 Game 层也使用自己的前缀（如游戏名称缩写）来进一步避免冲突。

如果确实发生冲突，可以：
1. 联系框架维护者协商前缀
2. 在自己的项目中给类名加前缀

---

## 如何贡献代码？

1. Fork 本仓库
2. 在 `main` 分支上创建 feature 分支
3. 遵循 CLAUDE.md 中定义的编码规范
4. 在 `test` 分支上编写测试
5. 提交 PR 到 `main` 分支

---

## 框架的学习曲线？

如果你熟悉以下概念，学习曲线会比较平缓：
- 依赖注入和分层架构
- ECS（Entity-Component-System）
- 事件驱动架构
- Godot 基础（GDScript、Node、Signal）

建议的学习路径：
1. 阅读 CLAUDE.md 理解框架原则
2. 阅读本手册的 getting-started 章节
3. 阅读 core-concepts 章节理解关键模式
4. 阅读 cookbook 中的具体示例
5. 自己动手集成一个功能

---

## 和 Unity/Unreal 框架的关系？

本框架的设计思想受以下来源启发，但完全是 Godot 原生的：

- **ECS 模式**：受 Unity ECS / DOTS 启发，但无 Burst Compiler 和 Job System（Godot 的限制）
- **Service Locator / DI**：受 ASP.NET Core 和 Angular 的 DI 容器启发
- **存档系统**：受多种 ORM 的 migration 机制启发
- **OperationResult**：受 HTTP REST API 和 Rust Result 类型启发

框架的目标不是复制 Unity/Unreal 的 API，而是在 Godot 中提供等价的架构能力。

---

## 可以在现有 Godot 项目中逐步引入吗？

可以。框架设计为可渐进式采用：

1. 先从 `OperationResult` 和 `ModuleLifecycle` 开始改善错误处理
2. 逐步引入 `EventBus` 替换手动信号连接
3. 有需要时再引入 ECS、Save、UI 等模块

框架内部模块之间有一定耦合（如 AppBootstrap 管理所有 Installer），但每个服务独立，可以按需使用。

---

## 存档数据坏了怎么办？

1. **自动检查**：框架在加载时校验版本号，版本不兼容会拒绝加载
2. **迁移修复**：通过注册 `GF_SaveVersionMigrator`，旧存档可自动迁移到新版本
3. **降级处理**：`on_load()` 中处理字段缺失的默认值
4. **备份建议**：建议在关键节点（Boss 战前、章节切换）自动创建备份存档

---

## 多人在线游戏能直接用这个框架吗？

当前框架的 LOCAL 模式适合单机或本地多人游戏。

Remote 和 Hybrid 模式是预留的，尚未实现。要实现真正的网络多人：

1. 需要自己实现 Command 的网络同步
2. 需要自己实现权威服务器逻辑
3. 框架预留的 `GF_CommandStrategy` 和 `GF_SaveStrategy` 可以作为扩展点
4. ECS Snapshot 系统可以作为网络状态同步的基础
