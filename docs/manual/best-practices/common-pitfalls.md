# 常见错误与反模式

本文档列出框架使用中 15 个最常见的错误，每个包含症状、原因和修复方案。

---

## 1. 在 System 中直接修改 World

**症状：** ECS System 执行后，查询结果不一致、组件数据异常消失或出现幽灵实体。

**原因：** System 的 `on_tick()` 直接调用 `world.add_component()` / `world.set_component()` / `world.despawn()`，绕过了 ECB（EcsCommandBuffer），导致迭代过程中修改存储使迭代器失效。

**修复：**

```gdscript
# ❌ 错误：直接在 System 中修改 World
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    for row in query.execute(p_world):
        # 直接修改 World 存储
        p_world.set_component(row.entity, &"Position", new_pos)
        p_world.despawn(row.entity)  # 迭代中删除实体！

# ✅ 正确：通过 ECB 写入，System 结束后统一 apply
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    for row in query.execute(p_world):
        p_ecb.set_component(row.entity, &"Position", new_pos)
        p_ecb.despawn(row.entity)  # 安全：延迟到 System 结束后执行
```

---

## 2. 忘记检查 OperationResult.is_fail()

**症状：** 服务调用失败后程序继续执行，后续操作基于无效数据，报错信息误导。

**原因：** 调用返回 `GF_OperationResult` 的方法后直接使用 `result.data`，未检查 `is_fail()`。

**修复：**

```gdscript
# ❌ 错误：不检查结果
func do_something() -> void:
    var result := save_service.load_slot(1)
    var data: Dictionary = result.data  # 如果加载失败，data 为 null
    restore_game(data)

# ✅ 正确：先检查再使用
func do_something() -> GF_OperationResult:
    var result := save_service.load_slot(1)
    if result.is_fail():
        _log.error("Game", "加载存档失败: %s" % result.error.message)
        return result
    var data: Dictionary = result.data
    restore_game(data)
    return GF_OperationResult.ok()
```

---

## 3. ECS 组件存 Node 引用

**症状：** 场景切换后实体组件中的 Node 引用变为无效（`is_instance_valid` 返回 false），或序列化存档时报错。

**原因：** ECS 组件是纯数据，不应持有 Node 引用。Node 的生命周期由场景树管理，ECS 实体的生命周期由 World 管理，两者不同步。

**修复：**

```gdscript
# ❌ 错误：组件存 Node 引用
world.add_component(entity, &"Visual", {"sprite": my_sprite_node})

# ✅ 正确：组件只存纯数据，通过 ID 关联渲染
world.add_component(entity, &"Visual", {"sprite_id": "player_01"})
# 渲染系统通过 sprite_id 查找对应的 Node
```

---

## 4. 用 preload/load 引用类

**症状：** 代码中使用 `const MyClass = preload("res://src/some/path/my_class.gd")` 或 `load()` 引用类。

**原因：** 框架要求所有类通过 `class_name` 全局注册，使用路径引用破坏了可维护性和可移植性。

**修复：**

```gdscript
# ❌ 错误：路径引用
const InputService = preload("res://addons/godot-game-framework/input/input_service.gd")
var service := InputService.new()

# ✅ 正确：使用 class_name 全局引用
var service := GF_InputService.new()
```

---

## 5. 在子线程中访问 Node 或 ECS World

**症状：** 子线程任务偶发崩溃，报错指向 `Node`、`SceneTree`、`World` 相关操作。

**原因：** Godot 的 Node、SceneTree 和框架的 ECS World 都不是线程安全的。子线程只能做纯数据计算。

**修复：**

```gdscript
# ❌ 错误：子线程中操作场景树
func _worker_task(p_token: GF_ThreadJobToken) -> void:
    var node := _some_node  # 捕获了外部 Node 引用
    node.position = Vector2(100, 200)  # 崩溃！

# ✅ 正确：子线程只做数据计算，结果在主线程回调中应用
func _worker_task(p_token: GF_ThreadJobToken) -> Dictionary:
    # 只做纯数据计算
    return {"new_position": _compute_path(data)}

# 在主线程回调中应用结果
func _on_task_completed(p_summary: GF_ThreadJobSummary) -> void:
    var result: Dictionary = p_summary.result.data
    _some_node.position = result["new_position"]
```

---

## 6. ISaveable 的 on_load 中访问未恢复的依赖

**症状：** 存档加载时 A 模块的 `on_load()` 访问了 B 模块的数据，但 B 尚未恢复——导致访问到默认值或空数据。

**原因：** 未正确设置 `restore_priority()`，依赖的数据还没有恢复。

**修复：**

```gdscript
# ❌ 错误：建筑数据在 on_load 中访问地形数据，但优先级设置不当
class_name BuildingData extends GF_ISaveable
func restore_priority() -> int: return 1  # 比地形还先恢复

# ✅ 正确：建筑依赖地形，优先级数值应大于地形
class_name MapData extends GF_ISaveable
func restore_priority() -> int: return 1   # 地形先恢复

class_name BuildingData extends GF_ISaveable
func restore_priority() -> int: return 50  # 建筑后恢复
```

---

## 7. 忘记在 _on_dispose 中清理资源

**症状：** 服务释放后，EventBus 继续收到回调、Scheduler 继续 tick、UI 面板泄漏。

**原因：** `_on_dispose()` 中没有取消订阅、注销回调、释放引用。

**修复：**

```gdscript
# ❌ 错误：_on_dispose 为空
func _on_dispose() -> GF_OperationResult:
    return GF_OperationResult.ok()

# ✅ 正确：清理所有注册
func _on_dispose() -> GF_OperationResult:
    _event_bus.clear_scope("my_system")
    _scheduler.unregister_callback("my_frame_callback")
    _save_service.unregister_saveable("my_data")
    _references.clear()
    return GF_OperationResult.ok()
```

---

## 8. 字符串事件名拼写错误

**症状：** 事件发布后监听方没有任何响应，无报错。

**原因：** `publish("item_collected")` 和 `subscribe("item_colleted")` 的字符串拼写不一致。

**修复：**

```gdscript
# ❌ 错误：拼写不一致
event_bus.publish("item_collected", data)
event_bus.subscribe("item_colleted", callback, "scope")  # collected vs colleted

# ✅ 正确：使用常量或 GF_EventDef 统一管理
const EVENT_ITEM_COLLECTED := "item_collected"
event_bus.publish(EVENT_ITEM_COLLECTED, data)
event_bus.subscribe(EVENT_ITEM_COLLECTED, callback, "scope")

# 或使用 GF_EventDef 结构化定义
```

---

## 9. configure() 之前就调用服务方法

**症状：** 服务初始化后直接调用方法，返回 `ERR_PRECONDITION` 或空指针错误。

**原因：** 服务继承 `GF_ModuleLifecycle`，`init_module()` 后进入 INITIALIZED 状态，但必须 `configure()` 注入依赖后才能使用。`finalize_configuration()` 之后才进入 READY 状态。

**修复：**

```gdscript
# ❌ 错误：未 configure 就使用
var save_service := GF_SaveService.new()
save_service.init_module()
save_service.save_all(0, meta)  # _provider 为 null！

# ✅ 正确：严格按照 UNINITIALIZED → init → INITIALIZED → configure → READY 顺序
var save_service := GF_SaveService.new()
save_service.module_name = "SaveService"
save_service.init_module()
save_service.configure(provider, path_resolver, log)
save_service.finalize_configuration()
# 现在可以安全使用
save_service.save_all(0, meta)
```

---

## 10. 在 _process 中做业务逻辑

**症状：** 游戏逻辑散落在多个脚本的 `_process()` 中，执行顺序不可控，难以测试和调试。

**原因：** 应通过 `GF_Scheduler` 注册帧回调，由框架统一管理 tick 顺序。

**修复：**

```gdscript
# ❌ 错误：业务逻辑散落在 _process 中
func _process(delta: float) -> void:
    _update_ai(delta)
    _check_triggers(delta)
    _update_animation(delta)

# ✅ 正确：通过 Scheduler 注册
func setup(p_scheduler: GF_Scheduler) -> void:
    p_scheduler.register_frame_callback(_update_ai, "ai_update")
    p_scheduler.register_frame_callback(_check_triggers, "trigger_check")
    p_scheduler.register_frame_callback(_update_animation, "anim_update")
```

---

## 11. 面板 close 后仍然持有引用

**症状：** 关闭面板后尝试访问面板上的控件，`is_instance_valid` 返回 false 或报 null 错误。

**原因：** 面板使用 `DESTROY_ON_CLOSE` 策略时，close 会 `queue_free()`，但业务代码仍持有强引用。

**修复：**

```gdscript
# ❌ 错误：持有面板强引用
var _panel: GF_UIPanel = null

func open_panel() -> void:
    _panel = _ui.open("MyPanel").data
    _panel.some_method()

func close_panel() -> void:
    _ui.close("MyPanel")
    # _panel 现在指向已释放的对象
    _panel.some_method()  # 错误！

# ✅ 正确：使用 WeakRef 或每次查询
func get_panel() -> GF_UIPanel:
    return _ui.get_panel("MyPanel")

func do_something() -> void:
    var panel := get_panel()
    if panel != null and is_instance_valid(panel):
        panel.some_method()
```

---

## 12. 存档版本号忘记递增

**症状：** 修改了存档数据结构后，旧存档加载时数据错乱或字段缺失，但没有迁移错误提示。

**原因：** 修改了 `on_save()` / `on_load()` 的数据结构，但没有递增 `GF_SaveVersion.CURRENT` 和提供对应的 `GF_SaveVersionMigrator`。

**修复：**

```gdscript
# 1. 递增版本号
# save_version.gd
const CURRENT: int = 2  # 从 1 递增到 2

# 2. 创建迁移器
class_name V1ToV2Migrator
extends GF_SaveVersionMigrator

func _init() -> void:
    from_version = 1
    to_version = 2

func migrate(p_data: Dictionary) -> GF_OperationResult:
    # 处理新增字段的默认值
    if p_data.has("player"):
        var player: Dictionary = p_data["player"]
        if not player.has("stamina"):
            player["stamina"] = 100  # v2 新增字段的默认值
    return GF_OperationResult.ok(p_data)

# 3. 注册迁移器
save_service.register_migrator(V1ToV2Migrator.new())
```

---

## 13. 在 ECB apply 之后再使用 ECB

**症状：** ECB 的 `apply()` 被调用后，继续向同一个 ECB 添加命令但不生效。

**原因：** ECB apply 后内部缓冲区已清空，后续命令需要新的 ECB 或重新 apply。

**修复：**

```gdscript
# ❌ 错误：apply 后继续使用
var ecb := world.create_command_buffer()
ecb.set_component(e1, &"Position", pos1)
ecb.apply(world)
ecb.set_component(e2, &"Position", pos2)  # 不会生效

# ✅ 正确：apply 后创建新 ECB
var ecb := world.create_command_buffer()
ecb.set_component(e1, &"Position", pos1)
ecb.apply(world)

ecb = world.create_command_buffer()
ecb.set_component(e2, &"Position", pos2)
ecb.apply(world)
```

---

## 14. 使用 print() 而非 GF_LogService

**症状：** 输出中混杂大量 `print()` 文本，无法按级别过滤，生产环境无法关闭调试输出。

**原因：** 框架统一使用 `GF_LogService` 进行分级日志，`print()` / `printerr()` 绕过了日志系统。

**修复：**

```gdscript
# ❌ 错误
print("配置已加载")
printerr("加载失败: " + error)

# ✅ 正确
_log.info("Config", "配置已加载")
_log.error("Config", "加载失败: %s" % error)
_log.debug("AI", "路径计算完成: %d 步" % path.size())
```

---

## 15. 事件回调中修改订阅列表

**症状：** 在事件回调中 `subscribe()` 或 `unsubscribe()` 时，程序行为异常或遗漏回调。

**原因：** GF_EventBus 在派发事件时会复制监听列表，但如果在回调中直接修改订阅（subscribe/unsubscribe），可能影响派发循环的完整性。

**修复：**

```gdscript
# ❌ 错误：在回调中直接取消订阅
func _on_event(_data) -> void:
    _event_bus.unsubscribe_token(_my_token.id)  # 在派发中修改

# ✅ 正确：GF_EventBus 使用 _pending_removes 延迟处理
# 框架已经安全处理了派发中的 unsubscribe
# 但最好避免在回调中做复杂的订阅变更
# 如果必须，使用 call_deferred 延迟
func _on_event(_data) -> void:
    call_deferred("_deferred_unsubscribe")
```
