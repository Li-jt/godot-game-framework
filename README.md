# 2D Game Framework (Godot 4.6)

分层架构 2D 游戏框架。所有类通过 `class_name` 全局注册，无需 `load()` 或路径导入。

## 版本

- **框架版本**: 0.1.0
- **引擎要求**: Godot 4.6+

## 分层

| 层 | 职责 |
|----|------|
| Application | 启动、生命周期、服务装配 |
| Core | 通用基类、OperationResult、GameServices、上下文 |
| Config | 配置加载、Def 校验 |
| Environment | AppConfig 加载/合并/校验 |
| Event | 事件总线 |
| Flow | 应用状态机 |
| Input | 输入服务、上下文栈 |
| Logging | 日志服务 |
| UI | 面板管理、主题、控件 |
| Engine | Godot 适配层（资源、场景、路径、调度） |
| Resource | 资源缓存与加载 |
| Runtime | 运行时模式（Local/Remote/Hybrid） |
| Save | 存档服务、版本迁移 |
| Network | 网络请求抽象 |
| DataAccess | Repository 接口、UnitOfWork |

## 在其他项目中使用

### 方式一：Git Submodule

```bash
cd your-game-project
git submodule add <this-repo-url> src/framework
```

### 方式二：直接复制

把 `src/framework/` 复制到你的 Godot 项目的 `src/framework/`。

### 项目结构要求

```
your-game/
├── project.godot
├── src/
│   ├── framework/      # ← 框架（来自本仓库）
│   ├── application/    # 你的 Application 层
│   ├── game/           # 你的 Game 层
│   └── shared/
├── content/
│   ├── scenes/
│   ├── ui/
│   └── ...
├── config/
│   └── app_config.json
└── tests/
```

### 启动流程

1. 创建主场景，根节点挂载 `GameBootstrap`（继承 `AppBootstrap`）
2. 实现 `_on_post_boot(context: GameServices)` 注册你的游戏面板、动作、Def
3. 框架自动处理配置加载、服务装配、状态机初始化

## 升级框架

```bash
cd src/framework
git pull origin main
```

注意 `CHANGELOG.md` 中的破坏性变更。
