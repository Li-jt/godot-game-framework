# GF_InputRebindService

> 适用版本: 0.3.0 | 继承: GF_InputRebindService -> RefCounted

## 概述

按键重绑定服务，管理"监听新按键"的完整流程：开始等待 -> 校验设备约束 -> 从事件创建绑定 -> 应用绑定（移除同槽位旧绑定）-> 处理冲突 -> 发射 `rebind_changed` 信号。

`GF_InputRebindService` 由 `GF_InputService` 内部创建和管理，配置了 `GF_ActionResolver` 引用。**游戏层通过 `GF_InputService` 的 `begin_rebind()` / `cancel_rebind()` 等方法间接使用**，直接使用本类的场景极少。

**使用场景**：

- 设置面板中点击"重新绑定"按钮时触发 `begin_rebind()`
- 等待用户按下新按键，通过 `handle_event_for_rebind()` 检测
- 保存/加载绑定配置文件
- 重置单个动作为默认绑定

**不适用场景**：

- 不要跳过 `GF_InputService` 直接操作此服务（会绕过统一入口）
- 不要手动修改 `GF_InputActionDef.bindings` 数组（绑定变更应通过此服务进行，确保冲突检测和信号发射）

## 枚举

### ConflictPolicy

绑定冲突处理策略。

| 值 | 描述 |
|----|------|
| `ALLOW` | 允许重复绑定（同一按键可绑定多个动作） |
| `WARN` | 检测到冲突时发出警告，但仍允许 |
| `REPLACE` | 检测到冲突时替换旧绑定 |

## 信号

### rebind_changed(action_id: String, slot: int)

绑定变更时发射。`slot = -1` 表示整组绑定被重置（由 `reset_action_to_default()` 触发）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| action_id | String | 发生变更的动作 ID |
| slot | int | 发生变更的槽位。`-1` 表示全部重置 |

## 属性

此服务不暴露公共成员属性。内部状态通过方法访问。

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| （无公共属性） | | | 通过方法访问所有功能 |

## 公共方法

### configure(p_resolver: GF_ActionResolver) -> void

配置依赖的 `GF_ActionResolver` 引用。在 `GF_InputService._on_init()` 中自动调用。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_resolver | GF_ActionResolver | 动作解析器实例 |

---

### begin_rebind(p_action_id: String, p_slot: int) -> bool

开始监听新按键绑定。设置 `_waiting = true` 后，下一个符合条件的输入事件将被捕获为新的绑定。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 要重绑定的动作 ID |
| p_slot | int | 绑定槽位（0=PRIMARY 主绑定, 1=SECONDARY 辅助绑定） |

**返回值：** `bool`，成功进入等待状态返回 `true`。

**错误码：**

| 错误码 | 触发条件 |
|--------|----------|
| 返回 false | 动作定义不存在 |
| 返回 false | 动作的 `rebindable` 为 `false` |

---

### cancel_rebind() -> void

取消当前的重绑定等待状态。调用后 `is_waiting()` 返回 `false`。

---

### is_waiting() -> bool

查询是否处于等待按键绑定的状态。

**返回值：** `bool`。

---

### handle_event_for_rebind(p_event: InputEvent) -> bool

检测传入的 `InputEvent` 是否是重绑定等待中的目标按键事件。如果是，则创建对应的 `GF_InputBinding` 并应用，然后自动结束等待状态并发射 `rebind_changed` 信号。

处理流程：
1. 检查是否在等待状态
2. 检查事件类型（仅接受 `InputEventKey`、`InputEventMouseButton`、`InputEventJoypadButton`；排除滚轮事件）
3. 检查设备约束（`can_bind_event_to_action`）
4. 从事件提取 `source` 和 `code`，创建 `GF_InputBinding`
5. 调用 `apply_binding()` 移除旧绑定并添加新绑定
6. 发射 `rebind_changed` 信号

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | InputEvent | Godot 原始输入事件（通常来自 `GF_InputRouter._input()`） |

**返回值：** `bool`，事件被成功捕获并应用为新绑定返回 `true`，否则 `false`。

---

### can_bind_event_to_action(p_event: InputEvent, p_def: GF_InputActionDef) -> bool

检查一个 `InputEvent` 是否符合目标动作定义的设备约束。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_event | InputEvent | 待检查的输入事件 |
| p_def | GF_InputActionDef | 目标动作定义 |

**返回值：** `bool`，事件来源符合动作的设备约束返回 `true`。

**检查规则：**

| 动作 DeviceConstraint | 允许的事件来源 |
|----------------------|---------------|
| `KEYBOARD_ONLY` | `KEYBOARD` |
| `MOUSE_ONLY` | `MOUSE_BUTTON`、`MOUSE_WHEEL` |
| `KEYBOARD_MOUSE` | `KEYBOARD`、`MOUSE_BUTTON`、`MOUSE_WHEEL` |
| `GAMEPAD_ONLY` | `GAMEPAD_BUTTON`、`GAMEPAD_AXIS` |
| `ANY` | 所有来源 |

---

### apply_binding(p_action_id: String, p_slot: int, p_binding: GF_InputBinding) -> bool

将新绑定应用到指定动作的指定槽位。会先移除同 `slot` 的旧绑定，然后添加新的。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 目标动作 ID |
| p_slot | int | 目标槽位 |
| p_binding | GF_InputBinding | 新的绑定实例 |

**返回值：** `bool`，动作定义存在且应用成功返回 `true`。

---

### reset_action_to_default(p_action_id: String) -> bool

将指定动作的所有绑定重置为 `register_action_def` 时由 `snapshot_default_bindings()` 保存的默认值。重置后发射 `rebind_changed(p_action_id, -1)` 信号。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 要重置的动作 ID |

**返回值：** `bool`，动作定义存在且重置成功返回 `true`。

**示例：**
```gdscript
# 在设置面板中点击"恢复默认"按钮
func _on_reset_default_button_pressed() -> void:
    input_service.reset_action_to_default("jump")
```

---

### save(p_path: String = "user://input_bindings_v1.tres") -> bool

将所有动作的当前绑定序列化保存到文件。使用 `GF_InputBindingConfig.from_defs()` 收集所有绑定的快照，然后序列化为 `.tres` 资源文件。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 保存路径，默认为 `"user://input_bindings_v1.tres"` |

**返回值：** `bool`，保存成功返回 `true`。

---

### load(p_path: String = "user://input_bindings_v1.tres") -> bool

从文件加载绑定配置并应用到所有已注册的动作定义。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_path | String | 加载路径，默认为 `"user://input_bindings_v1.tres"` |

**返回值：** `bool`，加载成功返回 `true`。文件不存在或解析失败返回 `false`。

---

## 完整使用示例

```gdscript
# 通过 GF_InputService 使用重绑定功能

# 1. 开始重新绑定跳跃键的主槽位
if input_service.begin_rebind("jump", 0):
    print("请按下新按键...")
else:
    print("该动作不允许重绑定")

# 2. 在 _input() 中自动检测（GF_InputRouter 内部调用）
# 当用户按下空格键时，handle_event_for_rebind 会自动：
#   - 验证设备约束
#   - 创建新的 GF_InputBinding
#   - 替换 jump 动作 slot 0 的旧绑定
#   - 发射 rebind_changed 信号

# 3. 监听绑定变更
# _rebind_service.rebind_changed.connect(_on_binding_changed)
func _on_binding_changed(action_id: String, slot: int) -> void:
    if slot == -1:
        print("动作 %s 已恢复默认" % action_id)
    else:
        print("动作 %s 槽位 %d 已更新" % [action_id, slot])

# 4. 保存绑定到文件
input_service.save_bindings()

# 5. 下次启动时加载
input_service.load_bindings()

# 6. 恢复默认
input_service.reset_action_to_default("jump")
```

## See Also

- [GF_InputService](./gf_input_service.md) -- 输入服务，游戏层通过此服务的重绑定方法操作
- [GF_InputActionDef](./gf_input_action_def.md) -- 动作定义，包含 `bindings`、`rebindable`、`device_constraint` 等配置
- [GF_InputBinding](./gf_input_binding.md) -- 单条设备绑定
- [GF_InputBindingConfig](./gf_input_binding_config.md) -- 绑定配置的序列化/反序列化
