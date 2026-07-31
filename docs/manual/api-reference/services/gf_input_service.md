# GF_InputService

> 适用版本: 0.3.0 | 继承: GF_InputService -> GF_ModuleLifecycle

## 概述

统一输入服务，是游戏层与输入系统交互的唯一入口。内部组合了 `GF_InputRouter`（事件采集）、`GF_ActionResolver`（动作解析）、`GF_InputPolicy`（策略过滤）、`GF_InputRebindService`（按键重绑定）和 `GF_InputGestureEngine`（手势检测）。游戏层只通过此服务注册动作定义和查询动作状态，**绝不接触底层原始事件**。

**使用场景**：

- 在 Application 层初始化后将 `GF_InputService` 注册到 `GameServices`
- 注册所有游戏逻辑动作（`register_action_def`）
- 每帧查询动作状态（`is_pressed`、`read_axis` 等）
- 打开 UI 时 `push_context` 限制可用动作
- 设置面板中调用 `begin_rebind` / `cancel_rebind` 实现按键重绑定
- 录制输入用于回放、调试或自动化测试

**不适用场景**：

- 不要直接用于读取特定设备的原始输入（使用 `GF_InputRouter` 底层的 `GF_DeviceNormalizer`）
- 不要绕过此服务直接调用 `GF_ActionResolver` 或 `GF_InputPolicy` 的公共方法

## 属性

此服务不暴露公共成员属性。所有状态通过内部组合的子模块管理。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### 生命周期

---

#### configure(_p_adapter = null) -> GF_OperationResult
空实现，供 `ModuleLifecycle` 框架调用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| _p_adapter | Variant | 预留适配器参数，当前未使用 |

**返回值：** 始终返回 `GF_OperationResult.ok()`。

---

### 依赖注入

---

#### set_ui_service(p_ui) -> void
注入 `GF_UIService` 实例，供内部 `GF_InputPolicy` 查询面板状态（如 `GAME_INPUT_BLOCK_ALWAYS` 面板是否打开）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_ui | GF_UIService | UI 服务实例，用于查询活跃面板的输入阻挡状态 |

**返回值：** 无。

**示例：**
```gdscript
var input := GF_InputService.new()
var ui := GF_UIService.new()
input.set_ui_service(ui)
```

---

### 路由器管理

---

#### get_or_create_router() -> GF_InputRouter
懒汉单例模式获取或创建 `GF_InputRouter` Node。首次调用时创建并配置路由器，后续调用返回已有实例。路由器负责在 `_input()` 中采集所有 Godot `InputEvent` 并转发给 `GF_ActionResolver`。

**返回值：** `GF_InputRouter` 实例。调用方应将其添加到场景树中。

**示例：**
```gdscript
var router := input_service.get_or_create_router()
if not router.is_inside_tree():
    add_child(router)
```

---

#### destroy_router() -> void
从场景树移除 `GF_InputRouter` 并释放。调用 `set_enabled(false)` 停止处理，然后 `queue_free()`。

**示例：**
```gdscript
input_service.destroy_router()
```

---

### 动作注册

---

#### register_action_def(p_def: GF_InputActionDef) -> void
注册一个完整的动作定义。内部会先调用 `p_def.snapshot_default_bindings()` 保存当前绑定为默认值（用于重置），然后将定义交给 `GF_ActionResolver`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_def | GF_InputActionDef | 动作定义实例，包含动作 ID、类型、绑定列表、死区等所有配置 |

**示例：**
```gdscript
var jump := GF_InputActionDef.new("jump", GF_InputActionDef.ActionType.BINARY) \
    .bind_key(KEY_SPACE) \
    .bind_gamepad_button(JOY_BUTTON_A)
input_service.register_action_def(jump)
```

---

#### get_action_def(p_action_id: String) -> GF_InputActionDef
查询已注册的动作定义。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作 ID，如 `"jump"`、`"move_right"` |

**返回值：** 对应 `GF_InputActionDef` 实例，未找到时返回 `null`。

---

#### get_all_action_ids() -> Array[String]
获取所有已注册动作的 ID 列表。

**返回值：** `Array[String]`，已注册动作 ID 数组。

---

### 动作查询

---

#### read_axis(p_action_id: String) -> float
读取一维轴的值。对于 `AXIS_1D` 动作返回连续值（-1.0 到 1.0），对于 `BINARY` 动作返回 0.0 或 1.0。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作 ID |

**返回值：** `float`，当前帧的最终输出值（已应用死区、灵敏度和平滑）。

---

#### is_pressed(p_action_id: String) -> bool
查询动作当前帧是否处于按下状态（值绝对值大于阈值）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作 ID |

**返回值：** `bool`，当前帧按下为 `true`。

---

#### is_just_pressed(p_action_id: String) -> bool
查询动作是否在当前帧刚被按下（上升沿检测）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作 ID |

**返回值：** `bool`，本帧刚从"未按下"变为"按下"时为 `true`。

---

#### is_just_released(p_action_id: String) -> bool
查询动作是否在当前帧刚被释放（下降沿检测）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作 ID |

**返回值：** `bool`，本帧刚从"按下"变为"未按下"时为 `true`。

---

### 上下文栈

---

#### push_context(p_ctx: GF_InputContext) -> void
将一个输入上下文压入上下文栈。如果栈顶已存在**相同优先级**的上下文，则替换栈顶（相同优先级互相顶替）。上下文栈控制当前哪些动作可用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_ctx | GF_InputContext | 输入上下文实例 |

**示例：**
```gdscript
# 进入 UI 模式：只允许 UI 相关动作
var ui_ctx := GF_InputContext.new()
ui_ctx.name = "ui_panel"
ui_ctx.priority = 100
ui_ctx.allowed_actions = ["ui_accept", "ui_cancel", "ui_navigate"]
input_service.push_context(ui_ctx)

# 关闭 UI 时
input_service.pop_context()
```

---

#### pop_context() -> void
弹出上下文栈顶的上下文，恢复到上一层上下文的动作限制。

---

#### clear_contexts() -> void
清空整个上下文栈（慎用，会导致所有已注册动作全部放行）。

---

### 按键重绑定

---

#### begin_rebind(p_action_id: String, p_slot: int) -> bool
开始监听新按键绑定。调用后，下一个 `GF_InputRouter` 收到的键盘/鼠标按键/手柄按钮事件将被捕获为新的绑定。`p_slot` 用于区分同一动作的多个绑定槽位（0=主绑定, 1=辅助绑定）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 要重绑定的动作 ID |
| p_slot | int | 绑定槽位（0=PRIMARY, 1=SECONDARY） |

**返回值：** `bool`，动作存在且 `rebindable=true` 时返回 `true`，否则 `false`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| 返回 false | 动作定义不存在 |
| 返回 false | 动作的 `rebindable` 为 `false` |

---

#### cancel_rebind() -> void
取消当前的重绑定等待状态，不再捕获下一个按键事件。

---

#### is_waiting_rebind() -> bool
查询是否处于等待绑定的状态。

**返回值：** `bool`，正在等待按键绑定时为 `true`。

---

#### handle_event_for_rebind(p_event: InputEvent) -> bool
将原始 `InputEvent` 喂给重绑定服务检测。通常在 `GF_InputRouter._input()` 中自动调用，游戏层一般不需要手动调用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | InputEvent | Godot 原始输入事件 |

**返回值：** `bool`，事件被重绑定服务消费（即已完成一次绑定操作）返回 `true`。

---

#### save_bindings(p_path: String = "user://input_bindings_v1.tres") -> bool
将所有动作的当前绑定保存到文件。使用 `GF_InputBindingConfig` 序列化。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 保存路径，默认为 `"user://input_bindings_v1.tres"` |

**返回值：** `bool`，保存成功返回 `true`。

---

#### load_bindings(p_path: String = "user://input_bindings_v1.tres") -> bool
从文件加载绑定并应用到所有已注册的动作定义上。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 加载路径，默认为 `"user://input_bindings_v1.tres"` |

**返回值：** `bool`，加载并应用成功返回 `true`，文件不存在或格式错误返回 `false`。

---

#### reset_action_to_default(p_action_id: String) -> bool
将指定动作的绑定重置为 `register_action_def` 时保存的默认值。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 要重置的动作 ID |

**返回值：** `bool`，动作定义存在时返回 `true`，否则 `false`。

---

### 向后兼容方法

---

#### register_action(p_action_id: String, _p_input_map_action: String = "") -> void
向后兼容的简写方法。创建一个默认的 `BINARY` 类型 `GF_InputActionDef` 并注册。新代码应使用 `register_action_def()` 提供完整配置。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作 ID |
| _p_input_map_action | String | 已废弃，忽略 |

---

#### register_actions(p_entries: Array) -> void
向后兼容的批量注册。遍历数组，对每个元素调用 `register_action()`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_entries | Array | 数组元素为 `Array`（取 `[0]` 为动作 ID）或 `String` |

---

#### set_move_keys(p_left: String, p_right: String, p_up: String, p_down: String) -> void
向后兼容的空操作。新代码应通过 `GF_InputActionDef` 的链式 API 绑定移动相关按键。

---

#### get_move_vector() -> Vector2
从 `"move_right"`、`"move_left"`、`"move_down"`、`"move_up"` 四个一维轴计算二维移动向量。

**返回值：** `Vector2`，x 为右-左，y 为下-上。

---

#### mouse_position() -> Vector2
获取当前鼠标在屏幕上的位置。

**返回值：** `Vector2`，等同于 `DisplayServer.mouse_get_position()`。

---

#### set_game_input_blocker(_p: Callable) -> void
向后兼容的空操作。新代码应使用 `push_context()` 控制可用动作。

---

#### set_game_input_enabled(p_enabled: bool) -> void
启用或禁用 `GF_InputRouter` 的事件处理。禁用后所有 `_input()` 事件被忽略。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_enabled | bool | `true` 启用，`false` 禁用 |

---

### 录制与回放

---

#### start_recording() -> void
开始录制输入帧数据。如果在录制中则忽略调用（防止误触丢失数据）。

---

#### restart_recording() -> void
强制重新开始录制，清除已有录制数据。

---

#### stop_recording() -> Dictionary
停止录制并返回录制数据。

**返回值：** `Dictionary`，包含 `"frames"` 等字段的录制数据。

---

#### snapshot_recording() -> Dictionary
获取当前录制快照，**不停止录制**。可用于实时保存或预览。

**返回值：** `Dictionary`，当前录制数据的快照。

---

#### is_recording() -> bool
查询是否正在录制。

**返回值：** `bool`。

---

#### replay(p_data: Dictionary) -> void
从录制数据开始回放。回放期间**真实输入被忽略**。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_data | Dictionary | 由 `stop_recording()` 或 `snapshot_recording()` 返回的数据 |

---

#### stop_replay() -> void
停止回放，恢复真实输入。

---

#### is_replaying() -> bool
查询是否正在回放。

**返回值：** `bool`。

---

#### save_recording(p_path: String) -> bool
将当前录制保存到 JSON 文件。**不停止录制**。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 文件路径 |

**返回值：** `bool`，保存成功返回 `true`。录制数据为空或文件写入失败返回 `false`。

---

#### load_and_replay(p_path: String) -> bool
从 JSON 文件加载录制数据并开始回放。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 文件路径 |

**返回值：** `bool`，加载成功并开始回放返回 `true`。文件不存在、无法打开或 JSON 解析失败返回 `false`。

---

## See Also

- [GF_InputActionDef](./gf_input_action_def.md) -- 动作定义，配置动作类型、绑定、参数
- [GF_InputContext](./gf_input_context.md) -- 输入上下文，控制可用动作白名单
- [GF_InputRebindService](./gf_input_rebind_service.md) -- 按键重绑定服务
- [GF_InputRouter](../engine/gf_input_router.md) -- 底层事件采集 Node
- [GF_InputPolicy](./gf_input_context.md#gf_inputpolicy) -- 输入策略判定层
- [GF_UIService](./gf_ui_service.md) -- UI 服务，输入阻挡依赖面板状态
