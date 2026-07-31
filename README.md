# 2D Game Framework (Godot 4.7)

分层架构 2D 游戏框架。所有类通过 `class_name` 全局注册，无需 `load()` 或路径导入。

## 版本

- **引擎要求**: Godot 4.7+
- **框架版本**: 0.1.0

## 分层

| 层 | 职责 |
|----|------|
| Application | 启动、生命周期、服务装配 |
| Core | 通用基类、OperationResult、GameServices、上下文 |
| ECS | 实体组件系统（World/Query/Command/Scheduler/Snapshot/Save） |
| Config | 配置加载、Def 校验 |
| Environment | AppConfig 加载/合并/校验 |
| Event | 事件总线 |
| Flow | 应用状态机 |
| Input | 输入服务、上下文栈、键位重绑定 |
| Logging | 日志服务 |
| UI | 面板管理、拖拽系统、输入阻挡 |
| Audio | 音频服务 |
| Engine | Godot 适配层（资源、场景、路径、调度、寻路） |
| Threading | 后台任务调度（优先级、取消、超时、重试、回调） |
| Resource | 资源缓存与加载 |
| Runtime | 运行时模式（Local/Remote/Hybrid） |
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
git init   # 如果还不是 Git 仓库，先初始化
git submodule add https://github.com/Li-jt/godot-game-framework.git src/framework

# 方式二：直接复制
cp -r godot-game-framework src/framework
```

### 项目结构

```
your-game/
├── project.godot
├── src/
│   ├── framework/      # ← 框架（来自本仓库）
│   ├── application/    # 你的 Application 层
│   ├── game/           # 你的 Game 层（ECS 组件/系统/命令）
│   └── shared/
├── content/
│   ├── scenes/
│   ├── ui/
│   └── defs/
└── config/
    └── app_config.json
```

### 启动流程

1. 创建主场景，根节点挂载你的 `AppBootstrap` 子类
2. 实现 `_on_post_boot(context: GameServices)` 注册 ECS 系统、游戏服务
3. 框架自动处理配置加载、服务装配、状态机初始化

### 编辑器工具（可选）

安装后可右键快速创建框架文件，详见 [安装指南](docs/manual/getting-started/installation.md#编辑器工具可选)。

## 当前实现状态

### 已完成

- 启动装配链路：Core → Engine → ECS → Services，ECS 默认接入
- ECS 核心：World、SparseSet/Archetype 双存储、Query、CommandBuffer、Scheduler、Snapshot、Save 适配
- ThreadingService：后台任务提交与主线程回收（优先级、取消、超时、重试）
- InputService v4.0：Action 归一化、上下文栈、键位重绑定、录制回放
- SaveService：ISaveable 自注册、多槽位、版本迁移链、恢复优先级、原子写入
- UI：面板管理（6 层 Canvas）、拖拽系统、输入阻挡策略
- 寻路框架：IPathGraph + ITraversal + IHeuristic 三层可插拔 A\*
- AudioService：Cue 播放、Bus 分组、SFX 池化

### 尚未完整

- Runtime 的 Remote/Hybrid 策略为预留，当前以 Local 为主
- Network 层为抽象基类 + Mock 客户端，尚无真实 HTTP/WebSocket 实现
- DataAccess 以 Repository 接口为主，缺少完整 Provider 闭环

## 升级框架

```bash
cd src/framework
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

详见 [CLAUDE.md](CLAUDE.md)。
