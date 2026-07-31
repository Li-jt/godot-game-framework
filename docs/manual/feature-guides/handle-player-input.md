# 处理玩家输入

## 场景描述

游戏需要响应玩家的键盘、鼠标和手柄操作。框架提供了一套完整的输入系统，将物理按键抽象为"逻辑动作"，游戏代码不再直接接触 Godot 的 `InputEvent`，只需查询动作状态。

本章覆盖：定义输入动作、绑定按键、查询状态、管理上下文栈、配置 UI 输入阻挡。

---

## 最小示例

```gdscript
# 1. 定义动作
var move_left := GF_InputActionDef.new("move_left", GF_InputActionDef.ActionType.AXIS_1D)
    .bind_key(KEY_A).bind_key(KEY_LEFT)

var jump := GF_InputActionDef.new("jump", GF_InputActionDef.ActionType.BINARY)
    .bind_key(KEY_SPACE).bind_gamepad_button(JOY_BUTTON_A)

# 2. 注册到 InputService
input_service.register_action_def(move_left)
input_service.register_action_def(jump)

# 3. 在 _process 中查询
func _process(_delta: float) -> void:
    if input_service.is_just_pressed("jump"):
        _character.jump()
    var axis := input_service.read_axis("move_left")
    _character.move(axis)
```

---

## 逐步解释

### 第一步：定义动作（GF_InputActionDef）

`GF_InputActionDef` 描述一个逻辑动作的全部属性。使用链式 API 配置：

```gdscript
var shoot := GF_InputActionDef.new("shoot", GF_InputActionDef.ActionType.BINARY)
    .bind_mouse(MOUSE_BUTTON_LEFT)          # 鼠标左键
    .bind_gamepad_button(JOY_BUTTON_RIGHT_TRIGGER)  # 手柄扳机
    .set_display_name("射击")
    .set_category("战斗")
```

#### ActionType 三种类型

| 类型 | 说明 | 典型用途 |
|------|------|---------|
| `BINARY` | 按下/释放（0 或 1） | 跳跃、交互、开枪 |
| `AXIS_1D` | 一维连续值（-1.0 ~ 1.0） | 缩放、油门/刹车 |
| `AXIS_2D` | 二维向量值 | 移动摇杆 |

选择建议：凡是需要连续读值的动作（移动、缩放、视角旋转）用 AXIS；凡是瞬发动作（跳跃、交互、换弹）用 BINARY。

#### bind 系列方法

每个 `bind_*` 方法对应一种物理输入源：

| 方法 | 参数 | 说明 |
|------|------|------|
| `bind_key(keycode, scale, mode)` | `Key` 枚举值 | 键盘按键，默认 mode=HELD |
| `bind_mouse(button, scale, mode)` | `MouseButton` 枚举值 | 鼠标按钮，默认 mode=IMPULSE |
| `bind_wheel(button, scale, mode)` | `MouseButton` 枚举值 | 鼠标滚轮，默认 mode=IMPULSE |
| `bind_gamepad_button(button, scale, mode)` | `JoyButton` 枚举值 | 手柄按钮，默认 mode=IMPULSE |
| `bind_gamepad_axis(axis, scale, mode, negative)` | `JoyAxis` 枚举值 | 手柄摇杆/扳机 |
| `bind_touch_pan(scale)` | — | 触控板双指滑动 |
| `bind_touch_magnify(scale)` | — | 触控板双指捏合 |

`scale` 参数用于 AXIS_1D/AXIS_2D 动作，乘到原始值上。例如 `bind_key(KEY_S, -1.0)` 让 S 键输出负方向值。

#### ComposeMode 合成模式

当一个动作绑定了多个输入源（如 W 键和左摇杆同时控制前进），用 `compose_mode` 控制如何合成：

| 模式 | 行为 | 示例 |
|------|------|------|
| `SUM` | 求和 | 缩放：Q 键和滚轮同时触发时累加 |
| `MAX` | 取最大值 | 油门：W=1.0 或扳机=0.5 时输出 1.0 |
| `AVERAGE` | 取平均值 | 多个设备同时输入时取平均 |

```gdscript
var zoom := GF_InputActionDef.new("zoom", GF_InputActionDef.ActionType.AXIS_1D)
    .bind_key(KEY_Q, 1.0).bind_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
    .set_compose(GF_InputActionDef.ComposeMode.SUM)
```

#### 死区、灵敏度和平滑

```gdscript
var look := GF_InputActionDef.new("look_horizontal", GF_InputActionDef.ActionType.AXIS_1D)
    .bind_gamepad_axis(JOY_AXIS_RIGHT_X)
    .set_deadzone(0.1)       # 绝对值小于 0.1 视为 0
    .set_sensitivity(2.0)    # 输出值乘 2
    .set_smoothing(0.3)      # 平滑系数，0=不平滑
```

- **deadzone**（默认 0.05）：消除摇杆漂移和误触
- **sensitivity**（默认 1.0）：乘数，用于鼠标灵敏度调节
- **smoothing**（默认 0.0）：每帧 lerp 到目标值，数值越大越平滑但响应越慢

#### DeviceConstraint 设备约束

限制动作只能由特定设备类型触发，用于改键面板的校验：

```gdscript
var aim := GF_InputActionDef.new("aim", GF_InputActionDef.ActionType.AXIS_2D)
    .bind_gamepad_axis(JOY_AXIS_RIGHT_X).bind_gamepad_axis(JOY_AXIS_RIGHT_Y, 1.0, GF_InputBinding.Mode.ANALOG, true)
    .set_device_constraint(GF_InputActionDef.DeviceConstraint.GAMEPAD_ONLY)
```

可选值：`ANY`（默认）、`KEYBOARD_ONLY`、`MOUSE_ONLY`、`KEYBOARD_MOUSE`、`GAMEPAD_ONLY`。

### 第二步：注册动作

```gdscript
input_service.register_action_def(move_left)
```

`register_action_def` 会自动调用 `snapshot_default_bindings()` 保存当前绑定为默认值，供后续"重置为默认"功能使用。

### 第三步：查询输入状态

四种查询方法，全部按 `action_id` 查询：

| 方法 | 返回类型 | 说明 |
|------|---------|------|
| `read_axis(action_id)` | `float` | 当前轴的连续值（-1.0 ~ 1.0） |
| `is_pressed(action_id)` | `bool` | 当前是否按住 |
| `is_just_pressed(action_id)` | `bool` | 本帧是否刚按下 |
| `is_just_released(action_id)` | `bool` | 本帧是否刚释放 |

对于 `read_axis`：BINARY 动作按下的绑定贡献 `scale` 值，多个绑定根据 `compose_mode` 合成。对于 `is_pressed`/`is_just_pressed`/`is_just_released`：只看 BINARY 动作，AXIS 动作在这些方法中返回 `false`。

### 第四步：输入上下文栈

上下文栈用于在不同游戏状态下限制可用动作。栈空时所有动作全部放行（默认 gameplay 模式）。

```gdscript
# UI 打开后，只允许 UI 相关动作
var ui_ctx := GF_InputContext.new()
ui_ctx.name = "ui"
ui_ctx.priority = 100
ui_ctx.allowed_actions = ["ui_accept", "ui_cancel"]
input_service.push_context(ui_ctx)

# UI 关闭后恢复
input_service.pop_context()
```

`GF_InputContext` 的三个控制字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `allowed_actions` | `Array[String]` | 白名单。非空时只有列表中的动作通过，其他的阻挡 |
| `blocked_action_ids` | `Array[String]` | 黑名单。仅当 `allowed_actions` 为空时生效。含 `"*"` 等效于全禁 |
| `block_all_game_actions` | `bool` | 设为 true 禁止所有游戏动作（优先级高于 allowed_actions） |

判定优先级：白名单命中 > 全禁 > 黑名单命中 > UI 阻挡 > 放行。

### 第五步：UI 输入阻挡

面板通过 `GF_UIPanelDef` 的 `input_block_mode` 和 `blocked_action_ids` 声明阻挡策略：

```gdscript
var def := GF_UIPanelDef.new()
def.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
def.blocked_action_ids = ["*"]  # 阻挡全部游戏输入
```

三种模式：

| 模式 | 行为 |
|------|------|
| `NONE` | 不阻挡游戏输入 |
| `ALWAYS` | 面板可见时阻挡指定的游戏动作（`cancel` 始终放行） |
| `POINTER_ONLY` | 鼠标位于面板区域内时才阻挡 |

---

## 完整示例：WASD 移动 + 鼠标点击射击

```gdscript
# ---- 定义（通常在 Game 层引导脚本中） ----

func _register_input_actions(input_service: GF_InputService) -> void:
    # 移动轴（四个方向各自独立，用 MAX 合成确保只取最大方向）
    input_service.register_action_def(
        GF_InputActionDef.new("move_right", GF_InputActionDef.ActionType.AXIS_1D)
            .bind_key(KEY_D).set_compose(GF_InputActionDef.ComposeMode.MAX)
    )
    input_service.register_action_def(
        GF_InputActionDef.new("move_left", GF_InputActionDef.ActionType.AXIS_1D)
            .bind_key(KEY_A).set_compose(GF_InputActionDef.ComposeMode.MAX)
    )
    input_service.register_action_def(
        GF_InputActionDef.new("move_up", GF_InputActionDef.ActionType.AXIS_1D)
            .bind_key(KEY_W).set_compose(GF_InputActionDef.ComposeMode.MAX)
    )
    input_service.register_action_def(
        GF_InputActionDef.new("move_down", GF_InputActionDef.ActionType.AXIS_1D)
            .bind_key(KEY_S).set_compose(GF_InputActionDef.ComposeMode.MAX)
    )

    # 二轴移动（替代方案，手柄左摇杆）
    input_service.register_action_def(
        GF_InputActionDef.new("move", GF_InputActionDef.ActionType.AXIS_2D)
            .bind_gamepad_axis(JOY_AXIS_LEFT_X)
            .bind_gamepad_axis(JOY_AXIS_LEFT_Y, 1.0, GF_InputBinding.Mode.ANALOG, true)
            .set_deadzone(0.15)
    )

    # 射击（鼠标 + 手柄）
    input_service.register_action_def(
        GF_InputActionDef.new("shoot", GF_InputActionDef.ActionType.BINARY)
            .bind_mouse(MOUSE_BUTTON_LEFT)
            .bind_gamepad_button(JOY_BUTTON_RIGHT_TRIGGER)
            .set_display_name("射击").set_category("战斗")
    )

    # 冲刺（按住 Shift）
    input_service.register_action_def(
        GF_InputActionDef.new("sprint", GF_InputActionDef.ActionType.BINARY)
            .bind_key(KEY_SHIFT)
            .set_display_name("冲刺").set_category("移动")
    )


# ---- 使用（在角色控制器中） ----

func _process(_delta: float) -> void:
    var input := _ctx.input as GF_InputService

    # 方案 A：四个独立方向轴查询
    var move := Vector2(
        input.read_axis("move_right") - input.read_axis("move_left"),
        input.read_axis("move_down") - input.read_axis("move_up")
    )
    _apply_movement(move)

    # 射击
    if input.is_just_pressed("shoot"):
        _fire_weapon()

    # 冲刺
    _is_sprinting = input.is_pressed("sprint")


# ---- UI 面板打开时阻挡游戏输入 ----

func _open_inventory() -> void:
    # 打开背包面板（面板的 blocked_action_ids = ["*"] 自动阻挡所有游戏输入）
    var result := ui_service.open("inventory")
    if result.is_fail():
        _log.error("UI", "打开背包失败: %s" % result.error.message)
```

---

## 常见变体

### 变体 1：双轴移动（手柄摇杆）

```gdscript
var move := GF_InputActionDef.new("move", GF_InputActionDef.ActionType.AXIS_2D)
    .bind_gamepad_axis(JOY_AXIS_LEFT_X)
    .bind_gamepad_axis(JOY_AXIS_LEFT_Y, 1.0, GF_InputBinding.Mode.ANALOG, true)
    .bind_key(KEY_D, 1.0).bind_key(KEY_A, -1.0)  # X 轴
    .bind_key(KEY_S, 1.0).bind_key(KEY_W, -1.0)  # Y 轴
    .set_deadzone(0.15)
```

读取时：`var vector := input_service.read_axis("move")` 返回 `Vector2`。

### 变体 2：缩放（键盘 + 滚轮）

```gdscript
var zoom := GF_InputActionDef.new("zoom", GF_InputActionDef.ActionType.AXIS_1D)
    .bind_key(KEY_E, 1.0).bind_key(KEY_Q, -1.0)
    .bind_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0).bind_wheel(MOUSE_BUTTON_WHEEL_DOWN, -1.0)
    .set_compose(GF_InputActionDef.ComposeMode.SUM)
    .set_sensitivity(0.1)
```

### 变体 3：单击/双击手势

```gdscript
var click := GF_InputActionDef.new("pointer", GF_InputActionDef.ActionType.BINARY)
    .bind_mouse(MOUSE_BUTTON_LEFT)
    .set_click_gesture("click_single", "click_double", 300)

# 短按触发 "click_single"，300ms 内连击触发 "click_double"
```

将 `click_single` 和 `click_double` 也注册为动作后，系统会自动根据点击间隔路由到正确的动作。

### 变体 4：手动输入上下文栈管理

```gdscript
# 进入对话
var dialog_ctx := GF_InputContext.new()
dialog_ctx.name = "dialog"
dialog_ctx.priority = 200
dialog_ctx.allowed_actions = ["ui_advance", "ui_skip"]
input_service.push_context(dialog_ctx)

# 进入暂停菜单
var pause_ctx := GF_InputContext.new()
pause_ctx.name = "pause"
pause_ctx.priority = 300
pause_ctx.block_all_game_actions = true
input_service.push_context(pause_ctx)

# 恢复（逐层 pop）
input_service.pop_context()  # 弹出 pause，回到 dialog
input_service.pop_context()  # 弹出 dialog，回到 gameplay
```

---

## 错误码

`register_action_def`、查询方法和 `push_context`/`pop_context` 本身不返回 `GF_OperationResult`（直接操作或返回简单值）。但底层的 `GF_ActionResolver` 在以下内部场景会产生日志警告：

| 场景 | 日志级别 | 说明 |
|------|---------|------|
| `get_def` 查不到 | — | 返回 `null`，查询方法返回默认值 |
| 未知 action_id 的查询 | — | `read_axis` 返回 0.0，`is_pressed` 返回 false |

---

## See Also

- [自定义按键绑定](./custom-key-bindings.md) -- 让玩家重新绑定按键
- [创建和管理 UI 面板](./create-ui-panels.md) -- 面板的输入阻挡配置
- [应用状态机](./app-state-flow.md) -- 状态切换时推送/弹出输入上下文
