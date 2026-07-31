# GF_InputActionDef

> 适用版本: 0.3.0 | 继承: GF_InputActionDef -> RefCounted

## 概述

动作定义类，描述一个逻辑动作的完整配置：类型、所有设备绑定、输出参数（死区、灵敏度、平滑）以及手势配置。支持**链式调用**配置，在一条语句中完成整个动作的设置。

**使用场景**：

- 在游戏初始化时创建并配置每个输入动作
- 通过 `GF_InputService.register_action_def()` 注册

**不适用场景**：

- 不要直接用于运行时查询动作状态（使用 `GF_InputService` 的查询方法）
- 不要手动修改 `bindings` 数组（使用 `GF_InputRebindService` 管理绑定变更）

## 枚举

### ActionType

动作输出类型。

| 值 | 描述 |
|----|------|
| `BINARY` | 按下/释放（跳跃、交互、开枪） |
| `AXIS_1D` | 一维连续轴（缩放、油门/刹车） |
| `AXIS_2D` | 二维向量轴（移动摇杆） |

### DeviceConstraint

绑定设备约束，限制重绑定时可接受的设备类型。

| 值 | 描述 |
|----|------|
| `ANY` | 任何设备都可绑定 |
| `KEYBOARD_ONLY` | 只能键盘 |
| `MOUSE_ONLY` | 只能鼠标 |
| `KEYBOARD_MOUSE` | 键盘或鼠标 |
| `GAMEPAD_ONLY` | 只能手柄 |

### ComposeMode

多个绑定同时触发时的合成模式。

| 值 | 描述 |
|----|------|
| `SUM` | 求和（缩放：Q 和滚轮同时触发时累加） |
| `MAX` | 取最大值（油门：W=1.0 或扳机=0.5 -> 输出 1.0） |
| `AVERAGE` | 取平均值 |

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| action_id | String | `""` | 动作唯一标识符，如 `"jump"`、`"move_right"` |
| action_type | int | `ActionType.BINARY` | 动作类型（BINARY / AXIS_1D / AXIS_2D） |
| bindings | Array[GF_InputBinding] | `[]` | 所有设备绑定列表（运行时可通过重绑定修改） |
| compose_mode | int | `ComposeMode.SUM` | 多绑定同时触发时的合成方式 |
| deadzone | float | `0.05` | 死区阈值，绝对值小于此值视为 0 |
| sensitivity | float | `1.0` | 灵敏度乘数，直接缩放输出值 |
| smoothing | float | `0.0` | 平滑系数（0=不平滑, 0.5=强平滑）。每帧 lerp 到目标值 |
| rebindable | bool | `true` | 是否允许玩家重绑定（设置面板用） |
| device_constraint | int | `DeviceConstraint.ANY` | 设备约束，限制重绑定时的设备类型 |
| display_name | String | `""` | 设置面板显示名 |
| category | String | `""` | 设置面板分类，用于分组显示 |
| default_bindings | Array[GF_InputBinding] | `[]` | 默认绑定快照（由 `snapshot_default_bindings()` 填充，用于重置） |
| gesture_profile | GF_InputGestureProfile | `null` | 手势配置（单击/双击检测），可为 null 表示无手势 |

## 公共方法

### _init(p_action_id: String, p_type: int = ActionType.BINARY) -> void

构造函数。必须提供动作 ID，类型默认为 `BINARY`。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_action_id | String | 动作唯一标识符 |
| p_type | int | 动作类型，取 `ActionType` 枚举值 |

**示例：**
```gdscript
var jump := GF_InputActionDef.new("jump")
var move := GF_InputActionDef.new("move_right", GF_InputActionDef.ActionType.AXIS_1D)
```

---

### 链式绑定方法

以下方法均返回 `self`，支持链式调用。

---

#### bind_key(p_keycode: Key, p_scale: float = 1.0, p_mode: int = GF_InputBinding.Mode.HELD) -> GF_InputActionDef

添加键盘按键绑定。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_keycode | Key | Godot 按键码，如 `KEY_SPACE`、`KEY_W` |
| p_scale | float | 值缩放，默认 1.0 |
| p_mode | int | 触发模式，默认 `GF_InputBinding.Mode.HELD`（持续按住） |

---

#### bind_mouse(p_button: MouseButton, p_scale: float = 1.0, p_mode: int = GF_InputBinding.Mode.IMPULSE) -> GF_InputActionDef

添加鼠标按钮绑定。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_button | MouseButton | 鼠标按钮，如 `MOUSE_BUTTON_LEFT` |
| p_scale | float | 值缩放 |
| p_mode | int | 触发模式，默认 `IMPULSE`（单次脉冲） |

---

#### bind_wheel(p_button: MouseButton, p_scale: float = 1.0, p_mode: int = GF_InputBinding.Mode.IMPULSE) -> GF_InputActionDef

添加鼠标滚轮绑定。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_button | MouseButton | 通常为 `MOUSE_BUTTON_WHEEL_UP` 或 `MOUSE_BUTTON_WHEEL_DOWN` |
| p_scale | float | 值缩放 |
| p_mode | int | 触发模式，默认 `IMPULSE` |

---

#### bind_gamepad_button(p_button: JoyButton, p_scale: float = 1.0, p_mode: int = GF_InputBinding.Mode.IMPULSE) -> GF_InputActionDef

添加手柄按钮绑定。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_button | JoyButton | 手柄按钮，如 `JOY_BUTTON_A`、`JOY_BUTTON_START` |
| p_scale | float | 值缩放 |
| p_mode | int | 触发模式，默认 `IMPULSE` |

---

#### bind_gamepad_axis(p_axis: JoyAxis, p_scale: float = 1.0, p_mode: int = GF_InputBinding.Mode.ANALOG, p_negative: bool = false) -> GF_InputActionDef

添加手柄摇杆/扳机轴绑定。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_axis | JoyAxis | 手柄轴，如 `JOY_AXIS_LEFT_X`、`JOY_AXIS_TRIGGER_RIGHT` |
| p_scale | float | 值缩放 |
| p_mode | int | 触发模式，默认 `ANALOG`（模拟量） |
| p_negative | bool | 为 `true` 时取负半轴值（如左摇杆向左时值为正） |

---

#### bind_touch_pan(p_scale: float = 1.0) -> GF_InputActionDef

添加触控板双指滑动手势绑定（使用 `delta.y` 作为输出值）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_scale | float | 值缩放 |

---

#### bind_touch_magnify(p_scale: float = 1.0) -> GF_InputActionDef

添加触控板双指捏合手势绑定（使用 `factor - 1.0` 作为输出值）。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_scale | float | 值缩放 |

---

### 链式参数方法

---

#### set_deadzone(p_val: float) -> GF_InputActionDef

设置死区阈值。输入绝对值小于此值时视为 0，避免摇杆漂移。

---

#### set_sensitivity(p_val: float) -> GF_InputActionDef

设置灵敏度乘数。输出值 = 原始值 * sensitivity。

---

#### set_smoothing(p_val: float) -> GF_InputActionDef

设置平滑系数。范围 0（不平滑）到约 0.5（强平滑）。每帧通过 `lerp` 向目标值过渡，避免输入跳变。

---

#### set_compose(p_val: int) -> GF_InputActionDef

设置多绑定合成模式。取 `ComposeMode` 枚举值。

---

#### set_device_constraint(p_val: int) -> GF_InputActionDef

设置设备约束。取 `DeviceConstraint` 枚举值，限制重绑定时可接受的设备类型。

---

#### set_display_name(p_val: String) -> GF_InputActionDef

设置设置面板显示名，如 `"跳跃"`、`"移动"`。

---

#### set_category(p_val: String) -> GF_InputActionDef

设置设置面板分类，如 `"移动"`、`"战斗"`、`"UI"`。

---

#### set_rebindable(p_val: bool) -> GF_InputActionDef

设置是否允许玩家重绑定。设为 `false` 则该动作不出现在设置面板中。

---

#### set_click_gesture(p_single: String, p_double: String, p_window_ms: int = 300, p_require_same: bool = true, p_drag_cancel: float = 8.0) -> GF_InputActionDef

配置单击/双击手势检测。设置后，`GF_InputGestureEngine` 会在检测到单击时触发 `p_single` 动作，双击时触发 `p_double` 动作。双击判定在 `p_window_ms` 毫秒内完成，单击会延迟到窗口结束后才触发。

**参数：**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_single | String | 单击触发的动作 ID |
| p_double | String | 双击触发的动作 ID |
| p_window_ms | int | 双击检测窗口（毫秒），默认 300 |
| p_require_same | bool | 是否要求两次点击目标相同，默认 true |
| p_drag_cancel | float | 拖拽取消阈值（像素），超过此距离取消 click 候选，默认 8.0 |

---

### 持久化方法

---

#### snapshot_default_bindings() -> void

将当前 `bindings` 数组深拷贝到 `default_bindings`，作为重置时的默认值。在 `GF_InputService.register_action_def()` 中自动调用，通常不需要手动调用。

---

## 完整示例

```gdscript
# 创建一个完整的玩家移动动作定义
var move_right := GF_InputActionDef.new("move_right", GF_InputActionDef.ActionType.AXIS_1D) \
    .bind_key(KEY_D) \
    .bind_key(KEY_RIGHT, 1.0, GF_InputBinding.Mode.HELD) \
    .bind_gamepad_axis(JOY_AXIS_LEFT_X) \
    .set_deadzone(0.1) \
    .set_sensitivity(1.0) \
    .set_smoothing(0.1) \
    .set_display_name("向右移动") \
    .set_category("移动") \
    .set_rebindable(true)

input_service.register_action_def(move_right)

# 带手势的交互动作
var interact := GF_InputActionDef.new("interact") \
    .bind_mouse(MOUSE_BUTTON_LEFT) \
    .set_click_gesture("interact", "interact_double") \
    .set_display_name("交互/双击交互") \
    .set_category("交互")

input_service.register_action_def(interact)
```

## See Also

- [GF_InputService](./gf_input_service.md) -- 输入服务，通过 `register_action_def()` 注册动作定义
- [GF_InputBinding](./gf_input_binding.md) -- 单条设备绑定
- [GF_InputGestureProfile](./gf_input_gesture_profile.md) -- 手势配置
- [GF_InputRebindService](./gf_input_rebind_service.md) -- 按键重绑定，修改 `bindings` 数组
