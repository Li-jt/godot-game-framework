# 框架架构文档

> 记录框架层各模块的设计决策、接口体系和扩展方向。

---

# 1. 整体分层

```
Application     ← 启动装配：AppBootstrap + ServiceRegistry + Installer
  ├── Core      ← 基类：ModuleLifecycle / OperationResult / GameServices / 上下文
  ├── Engine    ← Godot 适配：SceneHost / SceneFactory / Scheduler / ThreadingService / InputAdapter / 算法
  ├── Environment ← 配置加载：AppConfigLoader / EnvParser / ConfigSummary
  ├── Event     ← EventBus + EventToken + scope 清理
  ├── Flow      ← AppFlow 状态机（BOOT → MAIN_MENU → LOADING → IN_GAME ⇄ PAUSE）
  ├── Input     ← InputService + InputContext 栈 + InputAdapter
  ├── Logging   ← LogService + LogSink（控制台/文件/内存）
  ├── UI        ← UIService + UIPanel + UIPanelDef + UiContext 自动注入
  ├── Save      ← SaveService + ISaveable + SaveProvider + SaveVersionMigrator
  ├── Runtime   ← RuntimeService + CommandStrategy / SaveStrategy
  ├── Resource  ← ResourceService 缓存
  ├── Network   ← NetworkClient / NetworkRequest / NetworkResponse / MockClient
  └── DataAccess ← Repository 接口 (IWorld/Entity/Map/Save) + UnitOfWork + ChangeSet
```

---

# 2. 服务生命周期

```
ModuleLifecycle 状态机:
  UNINITIALIZED → INITIALIZING → INITIALIZED → CONFIGURING → READY
                    ↑ 失败 → FAILED                        ↑ Is_ready()

AppBootstrap 装配流程:
  _ready() → _run_boot_sequence()
    Phase 1: CoreInstaller       → 配置/日志/运行时/事件/流程
    Phase 2: EngineInstaller     → 资源/场景/调度/输入适配
    Phase 3: ServiceInstallerImpl → 存档/UI/音频/调试
    → 构建 ServiceRegistry
    → 构建 GameServices
    → _on_post_boot(context)     ← Game 层入口
    → transition_to(MAIN_MENU)
```

---

# 3. 自动注入体系

| 注入目标 | 注入者 | 注入时机 | 字段类型 |
|---------|--------|---------|---------|
| `UIPanel.ctx` | UIService | open() / _prewarm_one() | UiContext |
| `WorldRoot.ctx` | SceneHost | replace_world() | GameServices |

## 注入链路

```
ServiceInstallerImpl
  → 构建 UiContext（含 log/ui/input/event/scene/loc/save/config/flow/debug/audio）
  → UIService.configure(ui_context) → _panel_context = ui_context
    → open("panel") → panel.ctx = _panel_context

GameFlow.configure(ctx)
  → scene_host.set_world_context(ctx)
    → replace_world(path) → if root is WorldRoot: root.ctx = ctx; root._on_world_setup()
```

---

# 4. 场景树结构

```
SceneHost (scene_host.tscn, 编辑器可见)
├── WorldMount (Node2D)          ← 世界挂载点
│   └── GameWorldRoot             ← 运行时加载
├── GameCamera (Camera2D)        ← 游戏相机
└── UiCanvas (CanvasLayer)       ← UI 独立渲染层（不受相机影响）
    └── UIRoot (Control)
        ├── HudLayer
        ├── ScreenLayer
        ├── PopupLayer
        ├── TooltipLayer
        ├── SystemLayer
        └── DebugLayer
```

---

# 5. 存档系统

## ISaveable 接口

```
class_name MapData
extends ISaveable

func save_key() → String     # "map"
func on_save()  → Dictionary  # {width, height, cells}
func on_load(data) → void     # 恢复
```

## 自注册 + 自动收集

ISaveable 构造时 `call_deferred` 自动注册到 SaveService。存档/读取时 SaveService 遍历全部 ISaveable：

```
SaveService.save_all(slot, meta)
  → _build_save_data() → 遍历 _saveables → 收集 on_save()
  → Provider.save()

SaveService.load_and_restore(slot)
  → Provider.load_full() → 版本检测 + 迁移链
  → _restore_save_data() → 遍历 dict keys → 匹配 save_key → on_load()
```

## 存档格式

```json
{
  "world": { "elapsed_time": 42.5, "map_seed": 12345 },
  "map": { "width": 32, "height": 32, "cells": {...} },
  "unit_1": { "type": "unit", ... }
}
```

## 多态序列化

```
EntityRegistry.register("unit", factory)
EntityRegistry.register("building", factory)

存档中的实体带 "type" 字段 → 读档时查 EntityRegistry 创建正确类型
```

---

# 6. 寻路算法框架

## 三层拆分

```
IPathGraph     ← get_neighbors(pos), get_cost(from, to)    (地图结构)
ITraversal     ← is_walkable(pos)                          (通行规则，per-request)
IHeuristic     ← estimate(from, to)                        (启发式，可注入)
Pathfinder     ← find_path(from, to, graph, traversal)     (A* 可实例化)
```

## 设计要点

- **可实例化**：不是静态方法，构造时注入启发式
- **Per-request 定制**：每次 `find_path()` 可传不同 traversal，同一实例服务多种单位
- **Graph 不管通行**：graph 只提供拓扑结构，traversal 决定可行性
- **算法可替换**：实现同签名的 Dijkstra/BFS 即可

## 已有实现

| 类 | 说明 |
|----|------|
| `IPathGraph` | 接口 |
| `ITraversal` | 接口 |
| `IHeuristic` | 接口 |
| `ManhattanHeuristic` | 曼哈顿距离，四方向网格移动用 |
| `Pathfinder` | A* 实现，构造时注入 IHeuristic |

## 后期扩展

- [ ] `EuclideanHeuristic`（八方向/自由移动）
- [ ] `Dijkstra` 实现（高代价地形）
- [ ] RVO2 局部避障（`engine/algorithm/rvo2_agent.gd`，单位超过 10 个）

---

# 7. 输入系统

## InputContext 栈

```
栈空         → 所有动作放行（默认 gameplay）
push_context → 栈顶 context 决定允许哪些动作
pop_context  → 恢复上一层
```

## 上下文检查优先级

```
allowed（白名单）> block_all（全禁）> blocked（黑名单）> 放行
```

> 白名单优先：`allowed_actions = ["cancel"]` 时 ESC 始终可逃生

---

# 8. 线程任务系统

## 目标

- 统一后台计算任务提交能力（地图生成、批量寻路预计算、压缩等）
- 主线程安全回收任务结果，禁止子线程直接写场景树
- 提供优先级、取消、超时、重试、统计与回调

## 关键类型

| 类 | 职责 |
|----|------|
| `ThreadingService` | 提交/调度/回收线程任务 |
| `ThreadJobOptions` | 任务超时、重试、标签、优先级配置 |
| `ThreadJobHandle` | 任务取消、状态查询、结果读取 |
| `ThreadJobToken` | 协作式取消令牌 |
| `ThreadJobSummary` | 统一任务执行摘要 |

## 执行流程

```
Game/Framework 提交任务
  → ThreadingService.submit()
  → 队列按 priority 排序
  → WorkerThreadPool 后台执行
  → 主线程 pump() 回收结果
  → 回调 on_completed/on_failed/on_timeout/on_finished
```

## 线程边界

- 子线程：只做纯数据计算
- 主线程：写入世界状态、操作 Node/UI、触发回调
- 运行中取消：协作式（任务主动检查 token）

---

# 9. UI 面板生命周期

| 策略 | 关闭行为 | 适用 |
|------|---------|------|
| DESTROY_ON_CLOSE | `queue_free()` | 弹窗、确认框 |
| HIDE_ON_CLOSE | `hide()`，缓存复用 | 背包、商城 |
| PERSISTENT | 普通 close 拒绝 | HUD、用户信息 |
| MANAGED_BY_FLOW | 普通 close 拒绝 | Loading、黑幕 |

---

# 10. 配置系统

## 配置优先级

```
Framework 默认值
  → config/app_config.json
  → config/app_config.{env}.json
  → .env
  → .env.{env}
  → 命令行覆盖
  → 编辑器覆盖
```

## AppConfig 字段

```
app:    name, environment, version
runtime: mode(Local/Remote/Hybrid), enable_prediction, enable_rollback
network: api_base_url, ws_url, timeout, retry, use_mock_api
save:   provider, local_save_root, auto_save
logging: level, write_to_file, log_root
debug:  enable_debug_panel, show_prediction_state
```

---

# 11. 框架发布与版本管理

## 仓库关系

```
godot-game-framework (独立 Git 仓库)
  └── submodule → game/src/framework/

godot-game-starter (模板仓库)
  └── submodule → src/framework/  (同上)
```

## 升级流程

```bash
cd src/framework
git pull origin main
```

## 版本迁移

```
SaveVersion.CURRENT 递增
SaveVersionMigrator 子类实现 migrate(old) → new
SaveService.load_slot() 自动检测版本 + 执行迁移链
```

---

# 12. 关键设计原则

1. **class_name 全局引用**：所有类通过 `class_name` 注册，不写路径 import
2. **接口通过继承**：GDScript 无 `implements`，用基类虚方法实现接口语义
3. **上下文注入**：Game 层不访问 ServiceRegistry，通过 UiContext/GameServices 获取服务
4. **数据与表现分离**：WorldState/MapData ≠ 节点树，TileMapLayer ≠ 唯一真相
5. **可实例化优先于静态**：引擎算法（Pathfinder）可注入，不写死静态方法
6. **Game → Framework 单向依赖**：Framework 层不引用 Game 层类型
