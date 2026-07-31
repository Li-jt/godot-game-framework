# 按症状组织的常见问题

本文档按症状组织常见运行时问题，每个问题包含症状描述、原因分析和解决步骤。

---

## 1. "Service is not ready"

**症状：** 调用服务方法时返回 `ERR_PRECONDITION`，error.message 包含 "模块未 ready" 或 "not ready"。

**原因：** 服务尚未完成生命周期初始化。GF_ModuleLifecycle 要求 `init_module() → configure() → finalize_configuration()` 全部成功后服务才进入 READY 状态。

**解决步骤：**

1. 检查服务是否正确调用了 `init_module()`、`configure()`、`finalize_configuration()`
2. 检查 `configure()` 的返回值是否为 `is_ok()`
3. 检查依赖的服务是否也已完成初始化
4. 确认没有在启动流程中过早使用服务

```gdscript
# 检查服务状态
if not my_service.is_ready():
    _log.error("Init", "服务未就绪，当前状态: %d" % my_service.state)
    return
```

---

## 2. "Entity not found"

**症状：** 操作实体时返回 `ERR_NOT_FOUND`，提示 "实体不存在"。

**原因：** 实体已在之前的 tick 中被 despawn。

**解决步骤：**

1. 使用 `world.has_entity(entity_id)` 检查实体是否存在
2. 检查 System 的执行顺序：消费实体的 System 是否在被依赖的 System 之前运行
3. 确认 despawn 条件是否正确，避免意外删除实体
4. 如果使用 ECB，despawn 的实体在 apply 之前仍然对查询可见

```gdscript
# 安全操作实体
if not world.has_entity(entity_id):
    _log.warning("ECS", "实体 %d 不存在，跳过" % entity_id)
    return

# 或使用查询结果中的 is_alive 检查
for row in query.execute(world):
    if not row.is_alive:
        continue
    # 安全操作
```

---

## 3. "Component type not registered"

**症状：** 添加组件时报错，提示组件类型未注册。

**原因：** ECS World 要求组件类型在使用前必须先注册。

**解决步骤：**

1. 在 `_on_after_ecs_install()` 中注册所有组件类型
2. 确认组件类型名称拼写正确（区分大小写）
3. 使用 `StringName` 类型（`&"Position"`）而非 `String`

```gdscript
# 在启动时注册
func _on_after_ecs_install(p_deps: Dictionary) -> void:
    var world: GF_EcsWorld = p_deps.ecs_world
    world.register_component_type(&"Position")
    world.register_component_type(&"Health")
    world.register_component_type(&"Movement")
    # 确保所有使用的组件类型都已注册
```

---

## 4. "Save load failed"

**症状：** 存档加载失败，返回 `ERR_MIGRATION` 或 `ERR_IO` 或其他错误。

**原因：** 存档损坏、版本不匹配、缺少迁移器、文件路径错误等。

**解决步骤：**

1. 检查存档文件是否存在：`provider.list_slots()`
2. 检查存档版本是否与当前版本兼容
3. 如果版本不匹配，确认已注册对应的 `GF_SaveVersionMigrator`
4. 检查存档文件完整性（JSON 格式是否正确）
5. 检查 data 中每个 key 对应的 saveable 是否已注册

```gdscript
# 诊断存档问题
var slots := save_service.list_slots()
if slots.is_fail():
    _log.error("Save", "无法列出存档槽位: %s" % slots.error.message)
    return

for slot in (slots.data as Array):
    var result := save_service.load_slot(slot)
    if result.is_fail():
        _log.error("Save", "槽位 %d 加载失败: [%d] %s" % [
            slot, result.status_code, result.error.message
        ])
```

---

## 5. "Input action not responding"

**症状：** 按下按键后游戏没有任何反应，或特定动作无响应。

**原因：** 输入上下文栈阻挡了该动作。

**解决步骤：**

1. 检查当前上下文栈状态
2. 确认动作 ID 已注册（`register_action_def`）
3. 确认没有面板通过 `game_input_block_mode` 阻挡了输入
4. 检查动作是否在当前上下文的 `allowed_actions` 或 `blocked_action_ids` 中
5. 如果使用了 InputMap rebind，确认按键绑定是否正确

```gdscript
# 调试输入上下文
var all_actions := input.get_all_action_ids()
for action_id in all_actions:
    var pressed := input.is_pressed(action_id)
    if pressed:
        print("当前按下的动作: %s" % action_id)

# 检查上下文栈
print("当前上下文栈大小: %d" % input._policy.get_context_stack().size())
```

---

## 6. "UI panel not showing"

**症状：** 调用 `ui.open("PanelName")` 后面板没有显示。

**原因：** 面板路径错误、未注册、场景加载失败、Canvas Layer 不可见。

**解决步骤：**

1. 确认面板名称拼写正确
2. 确认面板已在 `GF_UIService` 注册（`register_panel` 或通过配置）
3. 检查面板场景路径是否存在，场景文件是否正确
4. 检查目标 Canvas Layer 是否存在且可见
5. 查看 GF_LogService 面板相关日志

```gdscript
# 调试面板状态
var panel := ui.get_panel("PanelName")
if panel == null:
    _log.error("UI", "面板 PanelName 不存在或未注册")
elif not is_instance_valid(panel):
    _log.error("UI", "面板 PanelName 已被释放")
elif not panel.visible:
    _log.warning("UI", "面板 PanelName 存在但不可见")
```

---

## 7. "Callback not called"

**症状：** EventBus 的 subscribe 回调没有被触发，或 Scheduler 的回调没有执行。

**原因：** scope 不匹配、回调对象已释放、回调 Callable 无效。

**解决步骤：**

1. 检查 `subscribe` 的 scope 参数是否与 `clear_scope` 一致
2. 检查回调对象是否已被 `_on_dispose` 清理了 scope
3. 如果回调绑定到 Node，检查 Node 是否仍在场景树中

```gdscript
# EventBus 调试
var count := event_bus.listener_count("my_event")
_log.debug("Debug", "事件 'my_event' 当前有 %d 个监听者" % count)

if count == 0:
    _log.warning("Debug", "事件 'my_event' 没有监听者，检查订阅代码")

# Scheduler 调试
# 确认回调名称未被重复注册覆盖
scheduler.register_frame_callback(_my_callback, "unique_name")
```

---

## 8. "Thread job timeout"

**症状：** 线程任务超时，返回 `ERR_TIMEOUT`，任务被标记为取消。

**原因：** 任务计算量过大、陷入死循环、未检查取消令牌、超时时间设置过短。

**解决步骤：**

1. 检查任务的 `timeout_ms` 设置是否合理
2. 在长时间循环中周期性检查 `token.is_cancel_requested()`
3. 将大任务拆分为多个小任务（分批处理）
4. 检查算法复杂度，优化热点路径
5. 查看 GF_ThreadingService 统计和慢任务日志

```gdscript
# 查看线程统计
var stats := threading.get_stats()
print("完成: %d, 失败: %d, 超时: %d, 取消: %d" % [
    stats["completed"], stats["failed"], stats["timed_out"], stats["cancelled"]
])
print("平均耗时: %.1f ms" % stats["avg_duration_ms"])

# 查看最近的慢任务
var recent := threading.get_recent_history(20)
for s in recent:
    if s.status_text() == "Timeout":
        print("超时任务: %s (%d ms)" % [s.name, s.duration_ms()])
```

---

## 9. "CommandBus handler not found"

**症状：** 提交命令后返回 `ERR_NOT_FOUND`，提示没有注册对应的 ICommandHandler。

**原因：** 没有为命令类型注册处理器。

**解决步骤：**

1. 确认命令类已实现 `GF_ICommand` 接口
2. 确认处理器已通过 `command_bus.register_handler()` 注册
3. 检查命令和处理器在同一 Runtime 模式下

```gdscript
# 注册命令处理器
command_bus.register_handler("BuildCommand", BuildCommandHandler.new())
command_bus.register_handler("MoveCommand", MoveCommandHandler.new())
```

---

## 10. "Scene transition stuck"

**症状：** 场景切换后停留在 LOADING 状态，游戏无法继续。

**原因：** 异步加载未完成、回调未触发、场景资源丢失。

**解决步骤：**

1. 检查场景资源路径是否正确
2. 确认异步加载的回调已正确设置
3. 检查 GF_AppFlow 的状态转换是否合法
4. 确认 LOADING 状态的 to 列表包含目标状态

```gdscript
# 调试 AppFlow 状态
_log.info("Flow", "当前状态: %s, 上一个: %s" % [
    app_flow.current_state, app_flow.previous_state
])

# 手动检查状态转换是否合法
var result := app_flow.transition_to(GF_AppFlow.STATE_IN_GAME)
if result.is_fail():
    _log.error("Flow", "状态转换拒绝: %s" % result.error.message)
```
