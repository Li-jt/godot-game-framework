# Godot Game Framework 用户手册

**Godot Game Framework** 是一个面向 Godot 4.7 的 2D 游戏框架，提供依赖注入、ECS 数据架构和统一错误处理三大核心能力。

## 谁适合用这个框架

| 你遇到的问题 | 框架如何解决 |
|---|---|
| 项目变大后脚本依赖混乱，`get_node()` 像蜘蛛网 | 依赖注入 + ServiceRegistry，每个服务声明它需要什么 |
| 数据和行为混在 Node 树里，存档/回放难实现 | ECS 分离数据与表现，数据层不依赖场景树 |
| 每个模块自己定义返回值，有的返回 `bool`，有的返回 `null`，有的返回 `int` | 统一 `GF_OperationResult`，所有失败都带错误码和上下文 |
| 服务初始化顺序失控，A 还没 ready 就被 B 调用了 | `GF_ModuleLifecycle` 7 态状态机，bootstrap 保证顺序 |
| 存档格式一变就要重写所有加载逻辑 | 存档版本迁移链，写一个 Migrator 即可兼容旧档 |
| 输入处理散落在 `_input()` / `_unhandled_input()` 中 | 设备归一化 + 动作上下文栈，输入和游戏逻辑解耦 |
| 面板管理混乱，弹窗层叠、输入穿透问题反复出现 | UI 服务统一管理面板生命周期、输入阻挡、层级 |
| claMod 系统没有标准挂载点 | Installer 生命周期 Hook，Mod 在明确时机注入服务/系统 |

**你不适合用这个框架，如果**：你只需要一个简单的单场景游戏，或者你只用 Godot 内置的 `_process()` + `get_node()` 就能完成所有逻辑。框架带来抽象成本，没有相应规模的项目不需要它。

## 架构全景图

框架按依赖方向从低到高分为五层：

```text
┌─────────────────────────────────────────────────────────┐
│  Game Layer（你的游戏）                                   │
│  组件定义 · 系统逻辑 · 配置内容 · UI面板 · 存档数据         │
├─────────────────────────────────────────────────────────┤
│  Service Layer（框架服务）                                 │
│  输入处理 · UI管理 · 存档管线 · 音频 · 日志 · 事件总线      │
│  资源配置 · 内容配置 · 本地化 · 调试 · 流程状态机           │
├─────────────────────────────────────────────────────────┤
│  Engine Adapter Layer（引擎适配）                          │
│  场景宿主 · 资源加载 · 文件系统 · 线程 · 寻路 · NodePool     │
├─────────────────────────────────────────────────────────┤
│  ECS Layer（数据架构）                                     │
│  World · Component · System · Query · CommandBuffer       │
│  Scheduler · Snapshot · SaveAdapter · Storage             │
├─────────────────────────────────────────────────────────┤
│  Core Layer（基础抽象）                                    │
│  ModuleLifecycle · OperationResult · GameServices          │
│  ContentDefRegistry · DefIdRegistry                      │
└─────────────────────────────────────────────────────────┘
```

- **Core** 层不依赖 Godot 场景树，纯 `RefCounted` 对象，可独立单元测试。
- **ECS** 层管理所有运行时数据，Entity 是整数 ID，Component 是纯数据，System 是纯逻辑。
- **Engine Adapter** 层统一 Godot API 的入口（文件读写、场景切换、资源加载），游戏层不应该直接 `load()` 或 `FileAccess`。
- **Service** 层提供开箱即用的游戏服务，每个服务继承 `GF_ModuleLifecycle`，通过 `configure()` 注入依赖。
- **Game** 层是你的游戏代码，单向依赖框架，框架绝不引用游戏类型。

数据流方向：Input（设备事件）→ System（ECS 逻辑）→ ECB（命令缓冲）→ World（组件更新）→ Presentation（渲染同步）。

## 阅读路径指引

| 你的目标 | 推荐阅读顺序 |
|---|---|
| 快速试一下 | [快速开始](getting-started/quick-start.md) → [安装](getting-started/installation.md) |
| 理解框架为什么这样设计 | [框架概览](getting-started/overview.md) → [模块生命周期](core-concepts/module-lifecycle.md) → [统一错误处理](core-concepts/operation-result.md) |
| 学习 ECS 数据架构 | [ECS 世界](core-concepts/ecs-world.md) → [实体与组件](core-concepts/entity-component.md) → [系统与查询](core-concepts/system-query.md) → [命令缓冲](core-concepts/command-buffer.md) |
| 配置项目 | [项目结构](getting-started/project-structure.md) → [配置文件](getting-started/configuration.md) |
| 理解服务装配 | [服务依赖注入](core-concepts/service-dependency.md) |
| 查命名规范 | [类名约定](core-concepts/class-name-convention.md) |

## 约定

本文档所有代码示例均使用框架的 `GF_` 前缀命名（框架内的实际类名），并遵循 GDScript 2.0 静态类型标注规范。

---

**下一步**: [框架概览](getting-started/overview.md)
