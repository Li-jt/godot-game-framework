# CLAUDE.md

本文件定义 Claude / AI 编程助手在 **godot-game-framework** 仓库中的工程级开发约束。
Claude 在生成代码、修改代码、重构、补文档、写测试、做架构决策时，必须遵守本文件。

本项目特征：

- 引擎：**Godot 4.7**
- 类型：**2D 游戏框架（插件）**
- 架构：**Application / Core / ECS / Engine / Input / UI / Save / Runtime 分层**
- 数据架构：**ECS（Entity-Component-System）SparseSet 存储**
- 运行模式：**Local / Remote / Hybrid（Remote/Hybrid 为预留）**
- 存档模式：**本地 + 版本迁移链**
- 部署方式：**Git 仓库（纯代码），其他项目通过 submodule 或复制引入**
- 代码组织：**所有类通过 `class_name` 全局注册，禁止路径 `load()`**

---

# 1. Claude 的最高优先级

Claude 在本项目中的首要目标是：

1. 框架必须可复用 — 不含任何具体游戏业务名词
2. 框架只负责**能力和机制**，不负责**玩法和规则**
3. `class_name` 全局引用 — 不写路径 `load()` / `preload()`
4. 所有公共 API 返回 `OperationResult`，不返回裸 `bool` 或 `null`
5. 保持 `Game → Framework` 单向依赖，Framework 绝不引用 Game 层类型
6. 接口通过继承 + 虚方法实现（GDScript 无 `interface` 关键字）
7. 数据与表现分离 — Node 树不是唯一真相源

如果某个实现虽然能运行，但会破坏上述原则，则**不得采用**。

---

# 2. 项目分层与职责

## 2.1 开发时的完整项目结构

本项目是纯代码框架。开发测试时，仓库根目录包含 `project.godot`（`.gitignore` 忽略，不提交）：

```text
godot-game-framework/
├── project.godot              ← 本地开发测试用，不提交
├── CLAUDE.md
├── README.md
├── CHANGELOG.md
├── plugin.cfg
├── .gitignore
├── application/               ← Bootstrap、生命周期、服务装配
├── core/                      ← 通用基类、OperationResult、上下文
├── ecs/                       ← ECS 基础设施
├── engine/                    ← Godot 适配层
├── environment/               ← AppConfig 加载/合并/校验
├── event/                     ← EventBus
├── flow/                      ← AppFlow 状态机
├── input/                     ← 输入服务
├── logging/                   ← 日志服务
├── ui/                        ← UI 服务 + 拖拽系统
├── save/                      ← 存档服务
├── runtime/                   ← Runtime 模式
├── network/                   ← 网络抽象
├── data_access/               ← Repository 接口
├── config/                    ← ConfigService
├── audio/                     ← AudioService
├── resource/                  ← ResourceService
├── localization/              ← 本地化
├── debug/                     ← DebugService
├── docs/                      ← 架构文档、缺陷清单、测试策略
└── tests/                     ← 测试（仅在 test 分支）
```

## 2.2 使用者项目结构

使用者将框架放到 `src/framework/` 下：

```text
your-game/
├── project.godot              ← 游戏自己的 project.godot
├── src/
│   ├── framework/             ← 框架（来自本仓库）
│   ├── application/           ← 游戏的 Application 层
│   ├── game/                  ← 游戏的 Game 层（ECS组件/系统/命令）
│   └── shared/
├── content/
│   ├── scenes/
│   ├── ui/
│   ├── defs/
│   └── ...
├── config/
│   └── app_config.json
└── tests/
```

## 2.3 各层职责边界

### Application
负责启动装配、服务注册、生命周期、配置加载。**Game 层定义的 AppBootstrap 子类放在这里**。

### Core
通用基类，不依赖任何 Godot 场景树：
- `ModuleLifecycle` — 所有服务的生命周期状态机
- `OperationResult` + `ErrorInfo` — 统一错误处理
- `GameServices` / `UiContext` / `GameplayContext` / `SaveContext` — 窄上下文
- `ContentDefRegistry` / `DefIdRegistry` — 通用内容注册表
- `DefJsonLoader` — JSON 加载工具

### ECS
ECS 基础设施（SparseSet 存储），全部是 RefCounted：
- World / Query / CommandBuffer / Scheduler / Snapshot / SaveAdapter
- 组件是纯数据类型，不持有 Node 引用
- 系统是纯逻辑计算，通过 ECB 写回 World

### Engine
Godot 引擎适配层，**有限度的适配**，不是重型封装：
- SceneHost / SceneFactory / Scheduler / ThreadingService
- PathResolver / FileSystemService / AssetLoadingService
- AudioRuntime / NodePool / RuntimeUtilities
- Pathfinder（A* 实现）

### Services
各领域服务（都继承 ModuleLifecycle）：
- input/ — 输入采集、动作解析、上下文栈、设备绑定
- ui/ — 面板管理、拖拽系统、输入阻挡
- save/ — 存档服务、版本迁移、ISaveable 收集
- config/ — 游戏 Def 注册和查询
- audio/ — AudioCue 播放
- resource/ — 资源缓存和 LRU 回收
- runtime/ — 运行时模式、CommandBus
- event/ — 事件总线
- flow/ — 应用状态机
- logging/ — 分级日志
- localization/ — 多语言
- debug/ — 调试统计
- network/ — 网络请求抽象
- data_access/ — Repository 接口

---

# 3. Framework 的硬边界

## 3.1 Framework 不得包含具体游戏业务名词

Claude 不得在 Framework 层引入以下类型概念：

- 任何具体游戏角色（Colonist, Unit, Enemy, NPC）
- 任何具体游戏物品（Sword, Potion, Wood, Iron）
- 任何具体游戏建筑（Farm, House, Barracks）
- 任何具体游戏系统（Hunger, Combat, Crafting, Trading）
- 任何具体游戏资源类型（Food, Gold, Mana）
- 任何具体 UI 面板名（InventoryPanel, ShopPanel）

这些必须属于 Game。Framework 只提供**抽象的机制**（输入、UI、存档、ECS、命令）。

## 3.2 Framework 负责能力，不负责规则

Framework 只负责：
- 资源加载机制 → 不负责"哪些资源何时加载"
- ECS 世界管理 → 不负责"实体应该有哪些组件"
- 命令总线 → 不负责"具体的建造/战斗/交易命令"
- 存档的序列化和反序列化 → 不负责"哪些数据需要存档"
- UI 面板管理 → 不负责"面板里有什么按钮"

## 3.3 Game → Framework 单向依赖

- `Game -> Framework` 允许
- `Framework -> Game` 禁止

Framework 层的 `class_name` 绝不引用 Game 层类型。

---

# 4. class_name 规则

## 4.1 所有类使用 class_name 全局注册

```gdscript
# ✅ 正确
class_name InputService
extends ModuleLifecycle

# ✅ 正确：在别处使用
var input := InputService.new()

# ❌ 错误：路径引用
const InputService = preload("res://src/framework/input/input_service.gd")
```

## 4.2 命名规范

| 元素 | 风格 | 示例 |
|------|------|------|
| 类名（class_name） | `PascalCase` | `InputService`, `EcsWorld`, `AppBootstrap` |
| 文件名 | `snake_case` | `input_service.gd`, `ecs_world.gd` |
| 变量/函数 | `snake_case` | `move_speed`, `calculate_path()` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_HEALTH`, `ERR_NOT_FOUND` |
| 信号 | `snake_case` 过去式 | `health_changed`, `flow_state_changed` |
| 私有成员 | `_` 前缀 | `_event_bus`, `_build_save_data()` |
| 布尔变量 | `is_`, `has_`, `should_`, `can_` 前缀 | `is_ready`, `has_component` |
| 枚举值 | `PascalCase` 或 `UPPER_SNAKE_CASE` | `State.IDLE`, `Source.KEYBOARD` |
| 接口类 | `I` 前缀 | `ISaveable`, `IEcsWorld`, `ICommand` |

## 4.3 class_name 与文件名必须匹配

```text
class_name: EcsWorld         → 文件名: ecs_world.gd
class_name: InputService     → 文件名: input_service.gd
class_name: ISaveable         → 文件名: i_saveable.gd
```

---

# 5. 类型标注规则

## 5.1 必须标注类型

- 所有公共方法的参数和返回值**必须**标注类型
- 成员变量**尽可能**标注类型
- `Variant` 仅在鸭子类型场景使用（如 ISaveable 的 saveable 参数）
- 数组标注元素类型：`Array[String]`, `Array[UIPanelDef]`
- 字典标注：`Dictionary`（GDScript 不支持泛型字典）

```gdscript
# ✅ 正确
func register_saveable(p_saveable) -> void:  # 鸭子类型，无标注
    var key: String = p_saveable.save_key()

# ✅ 正确
func get_def(p_type_key: String, p_id: String) -> Variant:

# ✅ 正确
func get_all(p_type_key: String) -> Dictionary:
```

## 5.2 内部变量使用类型推断

```gdscript
# ✅ 正确：内部变量用 :=
var result := some_function()
var key := entry["key"] as String

# ✅ 正确：成员变量显式标注
var _event_bus: EventBus = null
var _saveables: Dictionary = {}
```

---

# 6. OperationResult 规则

## 6.1 所有可能失败的操作返回 OperationResult

```gdscript
# ✅ 正确
func configure(p_provider: SaveProvider, p_log: LogService) -> OperationResult:
    if p_provider == null:
        return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "provider 不能为 null", module_name)
    return OperationResult.ok()

# ❌ 错误：返回 bool
func configure(p_provider: SaveProvider) -> bool:
    return p_provider != null

# ❌ 错误：返回 null 表示失败
func get_def(id: String) -> Variant:
    return null  # 调用方不知道失败原因
```

## 6.2 调用方必须检查 is_ok()

```gdscript
var result := service.do_something()
if result.is_fail():
    _log.error("Service", result.error.message)
    return result
# 使用 result.data
```

---

# 7. ModuleLifecycle 规则

## 7.1 所有服务继承 ModuleLifecycle

```gdscript
class_name MyService
extends ModuleLifecycle

func _on_init() -> OperationResult:
    return OperationResult.ok()

# 生命周期: UNINITIALIZED → INITIALIZING → INITIALIZED → CONFIGURING → READY
```

## 7.2 配置通过 configure() 注入，不通过 _init()

```gdscript
# ✅ 正确：通过 configure 注入依赖
func configure(p_provider: SaveProvider, p_log: LogService) -> OperationResult:
    _provider = p_provider
    _log = p_log
    return OperationResult.ok()

# ❌ 错误：在 _init 中访问外部服务
func _init() -> void:
    _provider = SomeGlobalService.get()  # 全局依赖
```

---

# 8. 接口设计规则

## 8.1 接口通过基类 + 虚方法实现

GDScript 无 `interface` 关键字，接口类命名以 `I` 开头：

```gdscript
# ✅ 接口
class_name ISaveable
extends RefCounted

func save_key() -> String:
    push_error("子类必须重写")
    return ""

func on_save() -> Dictionary:
    push_error("子类必须重写")
    return {}

func on_load(p_data: Dictionary) -> void:
    pass
```

## 8.2 鸭子类型用于跨继承链场景

当接口需要被 Node 子类和 RefCounted 子类同时实现时，使用鸭子类型：

```gdscript
# _is_saveable — 而不是 p_node is ISaveable
func _is_saveable(p_obj) -> bool:
    return p_obj.has_method("save_key") and p_obj.has_method("on_save") and p_obj.has_method("on_load")
```

因为 Node 和 RefCounted 是并行继承链，`is` 检查不适用于跨链场景。

---

# 9. ECS 规则

## 9.1 ECS 组件是纯数据

组件必须是 Dictionary 或 ReCounted DTO，不持有 Node 引用：

```gdscript
# ✅ 正确
world.add_component(entity, &"Position", {"x": 10.0, "y": 20.0})

# ❌ 错误
world.add_component(entity, &"Visual", {"sprite": my_sprite_node})
```

## 9.2 ECS 系统通过 ECB 写入

系统不直接修改 World 存储，通过 EcsCommandBuffer：

```gdscript
func on_tick(p_world: EcsWorld, p_ecb: EcsCommandBuffer, p_delta: float) -> void:
    # 只读查询
    for row in query.execute(p_world):
        # 写入通过 ECB
        p_ecb.set_component(row.entity, &"Position", new_pos)
```

## 9.3 ECS 世界版本管理

每次 mutation（spawn/despawn/add/remove/set）必须递增 `_version`。

---

# 10. 存档规则

## 10.1 ISaveable 注册路径

三种路径，各司其职：

| 路径 | 适用场景 | 调用方 |
|------|---------|--------|
| `collect_from_node(root)` | 场景树中的 Node-based ISaveable | SceneHost / on_world_switch |
| `child_entering_tree` 信号 | collect 之后的增量注册 | 框架自动 |
| `register_saveable(obj)` | 纯数据 ISaveable、全局 Service | Game 层手动调用 |

## 10.2 存档恢复顺序

使用 `restore_priority()` 声明恢复顺序，数值越小越先恢复：

```gdscript
# ECS 世界在 map 之后（entities 依赖地形）
func restore_priority() -> int: return 5

# 地形最先恢复
func restore_priority() -> int: return 1
```

## 10.3 版本迁移

修改存档格式时必须递增 `SaveVersion.CURRENT`，并提供 `SaveVersionMigrator` 子类。

---

# 11. UI 规则

## 11.1 面板生命周期

| 策略 | 关闭行为 | 适用 |
|------|---------|------|
| DESTROY_ON_CLOSE | `queue_free()` | 弹窗、确认框 |
| HIDE_ON_CLOSE | `hide()`，缓存复用 | 背包、商城 |
| PERSISTENT | 普通 close 拒绝 | HUD、用户信息 |
| MANAGED_BY_FLOW | 普通 close 拒绝 | Loading、黑幕 |

## 11.2 输入阻挡

面板通过 `UIPanelDef.game_input_block_mode` 声明阻挡策略：
- `GAME_INPUT_BLOCK_ALWAYS` — 打开即阻挡
- `GAME_INPUT_BLOCK_POINTER_ONLY` — 鼠标在面板区域内才阻挡

## 11.3 拖拽系统

三层设计：L1 协议层（UIDragManager + Handler）→ L2 便利层（UIDragSlot + SimpleDrag）→ L3 游戏层。

---

# 12. Input 规则

## 12.1 设备归一化

`DeviceNormalizer` 将 Godot InputEvent → `InputRawSignal`，下游不接触 Godot 事件类型。

## 12.2 动作上下文栈

```
栈空 → 全部放行（默认 gameplay）
push_context → 栈顶决定允许哪些动作
pop_context → 恢复上一层
```

优先级：白名单 > 全禁 > 黑名单 > 放行。

---

# 13. 文件组织规则

## 13.1 一个文件一个 class_name

每个文件职责单一：
- 200-400 行典型
- 800 行上限
- 超限时拆子模块

## 13.2 文件内顺序

```gdscript
extends Node
class_name MyClass

# 信号
signal something_happened()

# 枚举
enum State { IDLE, RUNNING }

# 常量
const MAX_COUNT := 100

# 导出变量
@export var speed: float = 300.0

# 公共变量
var current_state: State = State.IDLE

# 私有变量
var _event_bus: EventBus = null

# 生命周期
func _ready() -> void:
    pass

# 公共方法
func do_something() -> void:
    pass

# 私有方法
func _helper() -> void:
    pass
```

## 13.3 内部类放文件末尾

仅在单个文件内部使用的 helper class 放在文件最末尾：

```gdscript
# ... 所有公共和私有方法 ...

# ============================================================
# 内部类
# ============================================================

class _DefaultDragHandler extends UIDragHandler:
    # ...
```

---

# 14. 注释规则

## 14.1 公共 API 使用 `##` 文档注释

```gdscript
## 注册 ISaveable 实例。存盘时 save_all() 自动收集其 on_save() 数据。
## [br]
## [param p_saveable] 实现 save_key/on_save/on_load 的对象
func register_saveable(p_saveable) -> void:
```

## 14.2 复杂逻辑用 `#` 单行注释

```gdscript
# v4.0: 注入输入阻挡配置到面板实例
panel.set_input_block_config(...)
```

---

# 15. Godot 使用原则

## 15.1 不要做重型引擎封装

Engine Adapter 只统一关键入口：
- 资源加载 → AssetLoadingService
- 场景切换 → SceneHost
- Tick → Scheduler
- 输入 → InputService
- 音频 → AudioRuntime

**不要封装**：Vector2、Color、Transform2D、全量 SceneTree、全量 Resource 系统。

## 15.2 允许直接使用的 Godot API

Game 层在合适边界可以直接使用：
- `Vector2`, `Rect2`, `Color`, `Transform2D`
- `Node`, `Node2D`, `Control`
- `PackedScene`, `Resource`, `AudioStream`
- `InputMap`

## 15.3 不应散落直接使用的 API

- `load()` / `preload()` → 通过 ResourceService
- `FileAccess` / `DirAccess` → 通过 FileSystemService
- `_process()` 驱动系统 → 通过 Scheduler 注册
- `_input()` / `_unhandled_input()` → 通过 InputService

---

# 16. 错误处理规则

## 16.1 不允许静默吞错误

```gdscript
# ❌ 错误
func do_something() -> void:
    var result := service.configure(...)
    # 不检查 result

# ✅ 正确
func do_something() -> OperationResult:
    var result := service.configure(...)
    if result.is_fail():
        return OperationResult.wrap(result, module_name, "配置失败")
    return OperationResult.ok()
```

## 16.2 使用 LogService 而非 print()

```gdscript
# ❌ 错误
print("配置已加载")
printerr("加载失败")

# ✅ 正确
_log.info("Config", "配置已加载")
_log.error("Config", "加载失败: %s" % error_message)
```

---

# 17. 线程与异步规则

## 17.1 主线程安全

- 子线程只能做纯数据计算
- ECS World 写入必须在主线程
- Node 操作必须在主线程
- UI 更新必须在主线程
- 使用 `ThreadingService.submit()` 提交后台任务
- 使用 `pump()` 在主线程回收结果

## 17.2 节点安全

异步回调中必须检查节点有效性：

```gdscript
if is_instance_valid(_target_node):
    _target_node.do_something()
```

---

# 18. 测试规则

## 18.1 测试策略

详见 [docs/testing_strategy.md](docs/testing_strategy.md)。

要点：
- 纯逻辑 RefCounted 类 → GUT 单元测试，无场景树
- Node 子类 → `autoq()` 挂场景树后测试
- 接口 → 契约测试
- 跨模块协作 → 集成测试

## 18.2 ECS 测试必须覆盖

- spawn/despawn 生命周期
- add/get/set/remove/has 组件操作
- Query with/without/optional 过滤
- CommandBuffer apply/clear
- Snapshot build/apply 往返
- Scheduler system 注册和依赖顺序

## 18.3 Save 测试必须覆盖

- register/unregister/collect
- save_all/load_slot 往返
- 版本迁移链
- 恢复优先级
- 世界切换 on_world_switch
- 未注册 key 的降级处理

---

# 19. Claude 修改代码前检查清单

## 19.1 架构检查
- [ ] 是否破坏 Framework / Game 边界？
- [ ] 是否引入具体游戏业务名词？
- [ ] 是否破坏了 `class_name` 全局引用约定？
- [ ] 新增服务是否继承 `ModuleLifecycle`？
- [ ] 接口是否通过基类 + 虚方法定义（GDScript 无 interface）？

## 19.2 API 检查
- [ ] 公共 API 是否返回 `OperationResult`？
- [ ] 参数和返回值是否标注了类型？
- [ ] 公共方法是否有 `##` 文档注释？
- [ ] 错误是否通过 LogService 输出而非 print()？

## 19.3 ECS 检查
- [ ] 组件是否纯数据（不存 Node 引用）？
- [ ] 系统是否通过 ECB 写入 World？
- [ ] mutation 是否递增 version？
- [ ] 存储实现是否通过 IEcsStorage 接口？

## 19.4 Godot 检查
- [ ] 是否避免新增无意义的 Node 包装层？
- [ ] 是否避免把核心逻辑塞进 `_process()`？
- [ ] 是否避免直接散落 `load()` / `FileAccess`？
- [ ] 新增 Node 子类是否考虑了场景树生命周期？

## 19.5 代码质量检查
- [ ] 文件是否在 800 行以内？
- [ ] 函数是否在 50 行以内？
- [ ] 是否有超过 4 层嵌套？
- [ ] 是否有魔法数字（改用命名常量）？
- [ ] 是否使用不可变模式（创建新对象，不修改入参）？

---

# 20. Claude 明确禁止做的事

Claude 不得：

1. 在 Framework 层引入具体游戏业务类型（Colonist, Building, Sword, Farm 等）
2. Framework 引用 Game 层类型（破坏单向依赖）
3. 把 Game 层的项目配置写进 Framework
4. 使用路径 `load()` / `preload()` 引用类（应用 `class_name`）
5. 公共 API 返回裸 `bool` 或 `null`（应用 `OperationResult`）
6. 静默吞掉错误不返回
7. 使用 `print()` / `printerr()` 替代 LogService
8. 在 ECS 组件中存 Node 引用
9. 在异步线程中直接改 ECS World 或 Node 树
10. 新增重型 Godot 全量 API 封装层
11. 把 `_process()` 当做业务逻辑主入口（应用 Scheduler 注册）
12. 破坏 ISaveable 的鸭子类型设计

---

# 21. 一句话总约束

> **Framework 负责能力与机制（ECS 基础设施、服务抽象、输入/UI/存档引擎），Game 负责语义与规则（组件定义、系统逻辑、配置内容）；所有类通过 `class_name` 全局引用，公共 API 返回 `OperationResult`，接口通过基类 + 虚方法定义，Game → Framework 单向依赖。**

---

# 22. Git 分支与测试管理

## 22.1 双分支策略

本项目使用 **`main`（框架发布） + `test`（测试环境）** 双分支结构：

```
main  ← 干净框架代码，使用者拉取此分支
  │
  └── test  ← main 的完整超集，包含测试基础设施
```

| 内容 | main 分支 | test 分支 |
|------|----------|----------|
| 框架代码 | ✅ | ✅（通过 `git merge main` 同步） |
| `tests/` | ❌ 不存在 | ✅ 46 个测试文件 |
| `addons/gut/` | ❌ 不存在 | ✅ GUT 9.6.1 |
| `project.godot` | ❌（.gitignore） | ❌（.gitignore，本地自备） |

- **main**：使用者通过 submodule 或复制引入框架，拉取此分支只会得到纯框架代码。
- **test**：开发者内部完整测试环境，拉取后可直接 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit` 运行测试。

## 22.2 Claude 开发工作流

### 修改框架代码

```bash
git checkout main
# 修改框架代码、写文档
git commit -m "feat(ecs): 新增 xxx 功能"
```

### 编写/修改测试

```bash
git checkout test
git merge main               # 先把 main 的最新改动拉过来
# 编写新功能对应的测试
# 运行测试验证
godot --headless --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/ \
  -glog=1 -gexit
git add tests/
git commit -m "test(ecs): 为 xxx 新增测试用例"
```

### 同时修改框架和测试

1. 先在 `main` 上修改框架代码并提交
2. 切到 `test`，`git merge main` 同步过来
3. 在 `test` 上写测试并提交

## 22.3 关键约束

- **合并方向**：`main → test`（单向），**绝不** `test → main`
- **`.gitignore` 规则**：`addons/*` 忽略所有 addons，`!addons/gut/` 例外允许 GUT 在 test 分支被跟踪
- **`project.godot`**：在 `.gitignore` 中，任何分支都不提交。开发时本地持有即可
- **测试文件命名**：`test_<模块名>.gd`，按模块分目录
- **测试辅助类**：`tests/helpers/` 下的 Fake 类（FakeSaveProvider、FakeLogService 等）只能在 test 分支存在

## 22.4 运行测试命令

```bash
# 全部单元测试
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -glog=1 -gexit

# 单个模块
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/core/ -glog=1 -gexit

# 单个测试文件
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/core/test_operation_result.gd -glog=1 -gexit

# 集成测试
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/ -glog=1 -gexit
```

## 22.5 当前测试状态

- 测试文件：46 个
- 测试用例：268 个
- 通过率：85.8%（230 通过 / 30 失败）
- 详见 [docs/testing_strategy.md](docs/testing_strategy.md)
