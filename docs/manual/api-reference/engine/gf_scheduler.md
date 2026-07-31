# GF_Scheduler

> 适用版本: 0.3.0 | 继承: GF_Scheduler -> Node

## 概述

统一 Tick 驱动器。按 TickGroup 分组执行回调，同组内按 priority 排序。PHYSICS 组由 `_physics_process` 驱动（固定步长），其余组由 `_process` 驱动（可变帧率）。

适用场景：任何需要逐帧或固定间隔执行的回调（ECS 系统 tick、UI 更新、自动存档、调试面板刷新等）。不应在 `_process()` 或 `_physics_process()` 中直接实现游戏逻辑，应通过 Scheduler 注册。

## TickGroup 枚举

| 枚举值 | 数值 | 驱动源 | 典型用途 |
|--------|------|--------|---------|
| `PHYSICS` | -10 | `_physics_process`（固定 60Hz） | 物理计算（移动、碰撞响应） |
| `FRAME` | 0 | `_process`（可变帧率） | 渲染相关（相机跟随、动画更新） |
| `SIMULATION` | 10 | `_process`（可变帧率） | 游戏逻辑（在 PHYSICS/FRAME 之后运行） |
| `UI` | 50 | `_process`（可变帧率） | UI 更新 |
| `SAVE` | 80 | `_process`（可变帧率） | 自动保存 |
| `DEBUG` | 100 | `_process`（可变帧率） | 调试面板 |

**执行顺序:** 按数值从小到大依次执行（PHYSICS → FRAME → SIMULATION → UI → SAVE → DEBUG）。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `time_scale` | `float` | `1.0` | 全局时间缩放系数。设为 0.5 则所有 tick 的 delta 减半，0.0 暂停所有时间推进 |
| `paused` | `bool` | `false` | 全局暂停。暂停时所有组的 tick 均不执行 |

## 内部类

### TickHandle

用于注销回调的句柄对象。通过 `register()` 或 `register_interval()` 返回，不依赖回调名称即可注销。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `entry_name` | `String` | `""` | 注册时的回调名称 |

**方法:**

#### unregister() -> void

注销此句柄对应的回调。使用 WeakRef 引用 Scheduler，即使 Scheduler 已释放也不会报错。

```gdscript
var handle := scheduler.register(Scheduler.TickGroup.FRAME, "my_tick", _on_tick)
# 稍后注销
handle.unregister()
```

---

## 公共方法

### register(p_group: TickGroup, p_name: String, p_callback: Callable, p_priority: int = 0) -> TickHandle

注册逐帧回调。回调每帧执行一次（PHYSICS 组为每物理帧）。若同名回调已存在，先移除旧的再注册新的。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_group` | `TickGroup` | 执行阶段，决定在哪个 process 中运行 |
| `p_name` | `String` | 回调名称，用于后续查找和注销 |
| `p_callback` | `Callable` | 回调函数。PHYSICS 组的回调接收固定 delta（如 1/60），其余接收可变 delta |
| `p_priority` | `int` | 优先级，同组内数值越小越早执行。默认为 0 |

**返回值:** `TickHandle` 句柄，可用于后续注销。

**示例:**

```gdscript
# 注册游戏逻辑 tick
scheduler.register(Scheduler.TickGroup.SIMULATION, "ecs_tick", _on_ecs_tick, 0)

# 注册物理 tick
scheduler.register(Scheduler.TickGroup.PHYSICS, "movement", _on_physics, -5)

func _on_ecs_tick(delta: float) -> void:
    ecs_world.update(delta)

func _on_physics(delta: float) -> void:
    _apply_gravity(delta)
```

---

### register_interval(p_group: TickGroup, p_name: String, p_callback: Callable, p_interval: float, p_priority: int = 0) -> TickHandle

注册固定间隔回调。内部通过累加 delta 实现：当累计时间达到 `p_interval` 时触发回调，多余时间保留到下一周期。若同名回调已存在，先移除旧的再注册新的。

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_group` | `TickGroup` | 执行阶段 |
| `p_name` | `String` | 回调名称 |
| `p_callback` | `Callable` | 回调函数，接收 interval 值（不是 delta）作为参数 |
| `p_interval` | `float` | 触发间隔（秒）。PHYSICS 组按物理步长累积，其余按帧 delta 累积 |
| `p_priority` | `int` | 优先级，默认为 0 |

**返回值:** `TickHandle` 句柄。

**示例:**

```gdscript
# 每 5 秒触发一次自动保存
scheduler.register_interval(Scheduler.TickGroup.SAVE, "auto_save", _auto_save, 5.0, 0)

func _auto_save(interval: float) -> void:
    save_service.save_all()
```

---

### unregister_by_handle(p_handle: TickHandle) -> void

通过 TickHandle 注销回调。安全处理 null：传入 null 时不报错。

---

### unregister(p_name: String) -> void

根据名称注销回调（向后兼容接口）。回调不存在时静默忽略。

---

### has(p_name: String) -> bool

检查指定名称的回调是否已注册。

---

### pause() -> void

全局暂停。暂停后所有 TickGroup 的回调均不执行。`time_scale` 不受影响。

---

### resume() -> void

全局恢复。恢复后所有未被单独暂停的 TickGroup 正常执行。

---

### is_paused() -> bool

查询全局暂停状态。

---

### pause_group(p_group: TickGroup) -> void

暂停指定 TickGroup。重复调用不会报错。

**示例:**

```gdscript
# 打开菜单时暂停游戏逻辑
scheduler.pause_group(Scheduler.TickGroup.SIMULATION)
```

---

### resume_group(p_group: TickGroup) -> void

恢复指定 TickGroup。

---

### is_group_paused(p_group: TickGroup) -> bool

查询指定 TickGroup 是否被暂停。

---

### set_time_scale(p_scale: float) -> void

设置全局时间缩放系数。传入值会被 clamp 到 `>= 0`。

- `1.0`：正常速度
- `0.5`：半速
- `0.0`：暂停时间推进（注意：不等同于 `pause()`，回调仍会执行但 delta 为 0）

**示例:**

```gdscript
# 子弹时间效果
scheduler.set_time_scale(0.2)
```

---

### is_runtime_ready() -> bool

运行时就绪检查。Scheduler 始终返回 `true`（无额外配置要求）。

## 内部机制

### 排序与脏标记

注册新回调时设置 `_dirty = true`。下一次 `_process()` 或 `_physics_process()` 时先排序再执行，排序规则为：先按 TickGroup 数值升序，同组内按 priority 升序。

### 无效回调自动清理

每帧执行时检测 Callable 是否有效，无效的（如引用的对象已被释放）自动移除。

### PHYSICS 与 FRAME 分离

- PHYSICS 组由 `_physics_process()` 驱动，使用固定步长，适合物理计算
- 其余组由 `_process()` 驱动，使用可变帧 delta，适合逻辑和 UI

两组互不干扰，PHYSICS 组不会因渲染帧率波动而跳过步骤。

## 使用示例

```gdscript
# 初始化
var scheduler := GF_Scheduler.new()
add_child(scheduler)

# 注册各类 tick
scheduler.register(Scheduler.TickGroup.PHYSICS, "movement", _on_physics, -5)
scheduler.register(Scheduler.TickGroup.SIMULATION, "ecs", _update_ecs, 0)
scheduler.register(Scheduler.TickGroup.UI, "hud", _update_hud, 0)
scheduler.register_interval(Scheduler.TickGroup.SAVE, "auto_save", _auto_save, 5.0)

# 控制
scheduler.set_time_scale(0.5)           # 半速
scheduler.pause_group(Scheduler.TickGroup.SIMULATION)  # 暂停游戏逻辑

# 注销
scheduler.unregister("ecs")
```

## See Also

- [GF_SceneHost](./gf_scene_host.md) -- 场景宿主（Scheduler 通常作为其子节点）
- [GF_ModuleLifecycle](../core/gf_module_lifecycle.md) -- 服务生命周期基类
