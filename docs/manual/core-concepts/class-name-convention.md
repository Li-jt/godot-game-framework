# 类名约定

**类比**：在邮局，每封信都有标准的地址格式——国家、城市、街道、门牌号。如果每个人的地址写法都不同，信件就会丢失。`class_name` 约定就是框架的地址格式：确保 Godot 能找到每个类、每个人都知道类名代表什么。

## 核心规则：class_name 全局引用

框架所有类型通过 `class_name` 全局注册。在任何文件中使用框架类型时，**禁止**使用 `load()` 或 `preload()`：

```gdscript
# ✅ 正确：通过 class_name 引用
var world := GF_EcsWorld.new()
var result := GF_OperationResult.ok()

# ❌ 错误：通过路径引用
const EcsWorld = preload("res://src/framework/ecs/core/ecs_world.gd")
var world := EcsWorld.new()
```

**为什么禁止路径引用？**
- `class_name` 让 Godot 自动发现和加载类型，不需要关心文件位置
- 路径引用在重构时断裂（文件移动或改名时，所有 `preload` 都需要更新）
- `class_name` 统一了引用风格——你只需要记住类名，不需要记住它在哪个目录

## 命名规范表

| 元素 | 风格 | 示例 |
|---|---|---|
| 类名（`class_name`） | `PascalCase` | `GF_InputService`、`GF_EcsWorld`、`GF_AppBootstrap` |
| 文件名 | `snake_case` | `input_service.gd`、`ecs_world.gd`、`app_bootstrap.gd` |
| 变量/函数 | `snake_case` | `move_speed`、`calculate_path()`、`get_version()` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_HEALTH`、`ERR_NOT_FOUND`、`GROUP_SIMULATION` |
| 信号 | `snake_case` 过去式 | `health_changed`、`flow_state_changed`、`entity_spawned` |
| 私有成员 | `_` 前缀 | `_event_bus`、`_build_save_data()`、`_validate()` |
| 布尔变量 | `is_`、`has_`、`should_`、`can_` 前缀 | `is_ready`、`has_component`、`should_save`、`can_move` |
| 枚举值 | `PascalCase` 或 `UPPER_SNAKE_CASE` | `State.IDLE`、`Source.KEYBOARD` |
| 接口类 | `I` 前缀 | `GF_ISaveable`、`GF_IEcsWorld`、`GF_ICommand` |

## 文件名与 class_name 必须匹配

```text
class_name: GF_EcsWorld       → 文件名: ecs_world.gd
class_name: GF_InputService   → 文件名: input_service.gd
class_name: GF_ModuleLifecycle → 文件名: module_lifecycle.gd
```

**为什么匹配？**
- 当你在 Godot 编辑器中搜索类名时，你能立刻知道去哪个文件找它
- 当你在文件系统中看到文件名时，你能猜到里面定义的类名
- 违反这个约定会导致认知负担（"这个文件里到底定义了什么类？"）

## GF_ 前缀说明

框架所有公开的 `class_name` 以 `GF_` 开头，与你的游戏代码清晰区分。

```text
GF_ 前缀 → 框架类型   (GF_EcsWorld, GF_InputService, GF_OperationResult)
无前缀   → 你的游戏类型 (PlayerController, InventorySystem, HealthComponent)
```

**好处**：
- 自动补全时一眼看出哪些是框架类（输入 `GF_` 列出所有框架 API）
- 避免命名冲突（你不会定义 `PlayerController` 但永远不会定义 `GF_PlayerController`）
- 重构安全（框架更新不会覆盖你的代码）

## 接口类命名

GDScript 没有 `interface` 关键字。框架使用以 `I` 开头的 **`GF_`** 基类定义契约：

```gdscript
class_name GF_ISaveable
extends RefCounted

func save_key() -> String:
    push_error("子类必须重写")
    return ""

func on_save() -> Dictionary:
    return {}

func on_load(p_data: Dictionary) -> void:
    pass
```

接口类命名模式：`GF_I` + 角色名。

| 接口 | 角色 |
|---|---|
| `GF_ISaveable` | 可被存档系统收集和恢复的对象 |
| `GF_IEcsWorld` | ECS World 的抽象接口 |
| `GF_IEcsQuery` | ECS Query 的抽象接口 |
| `GF_IEcsCommandBuffer` | ECB 的抽象接口 |
| `GF_ICommand` | 可被 CommandBus 执行的命令 |

## 服务类命名

| 模式 | 示例 |
|---|---|
| `GF_` + 领域 + `Service` | `GF_InputService`、`GF_SaveService`、`GF_AudioService`、`GF_LogService`、`GF_UIService`、`GF_ConfigService`、`GF_ResourceService`、`GF_LocalizationService`、`GF_DebugService`、`GF_RuntimeService`、`GF_ThreadingService`、`GF_FileSystemService` |

## 文件内组织顺序

每个 `.gd` 文件内的代码按以下顺序组织：

```gdscript
extends Node
class_name MyClass

# 1. 信号
signal something_happened(data: Dictionary)

# 2. 枚举
enum State { IDLE, RUNNING, PAUSED }

# 3. 常量
const MAX_COUNT := 100
const DEFAULT_SPEED := 300.0

# 4. @export 变量
@export var speed: float = 300.0
@export var is_enabled: bool = true

# 5. 公共变量
var current_state: State = State.IDLE
var entity_count: int = 0

# 6. 私有变量
var _event_bus: GF_EventBus = null
var _is_initialized: bool = false

# 7. 生命周期方法
func _ready() -> void:
    pass

# 8. 公共方法
func do_something() -> GF_OperationResult:
    return GF_OperationResult.ok()

# 9. 私有方法
func _validate_input(p_value: Variant) -> bool:
    return true

# 10. 内部类（仅在本文件使用的 helper class）
class _InternalHelper extends RefCounted:
    pass
```

## 文件职责单一

- 一个文件定义一个 `class_name`
- 200-400 行是理想的文件长度
- 800 行是硬上限（超过则拆分）
- 如果文件需要"内部辅助类"，定义在文件末尾

---

**下一步**: 返回[文档首页](../index.md) 选择下一步阅读方向，或查阅具体模块文档。
