## InputActionDef — 输入动作定义（v3.0 重写）。
## 描述一个逻辑动作的类型、所有设备绑定和输出参数。
## 支持链式调用配置：.bind_key(...).bind_wheel(...).set_deadzone(...)
class_name InputActionDef
extends RefCounted

## 动作类型
enum ActionType {
	BINARY,   ## 按下/释放（跳跃、交互、开枪）
	AXIS_1D,  ## 一维连续轴（缩放、油门/刹车）
	AXIS_2D,  ## 二维向量轴（移动摇杆）
}

## 设备约束
enum DeviceConstraint {
	ANY,             ## 任何设备都可绑定
	KEYBOARD_ONLY,   ## 只能键盘
	MOUSE_ONLY,      ## 只能鼠标
	KEYBOARD_MOUSE,  ## 键盘或鼠标
	GAMEPAD_ONLY,    ## 只能手柄
}
## 绑定合成模式
enum ComposeMode {
	SUM,     ## 求和（缩放：Q 和滚轮同时触发时累加）
	MAX,     ## 取最大值（油门：W=1.0 或 扳机=0.5 → 输出 1.0）
	AVERAGE, ## 取平均值
}

## 动作 ID
var action_id: String = ""
## 动作类型
var action_type: int = ActionType.BINARY
## 所有设备绑定
var bindings: Array[InputBinding] = []
## 绑定合成模式
var compose_mode: int = ComposeMode.SUM
## 死区（绝对值小于此值视为 0）
var deadzone: float = 0.05
## 灵敏度乘数
var sensitivity: float = 1.0
## 平滑系数（0=不平滑, 0.5=强平滑）。每帧 lerp 到目标值。
var smoothing: float = 0.0
## 是否可重绑定（设置面板用）
var rebindable: bool = true
## 设备约束
var device_constraint: int = DeviceConstraint.ANY
## 设置面板显示名
var display_name: String = ""
## 设置面板分类
var category: String = ""
## 默认绑定（不可删除，用于重置）
var default_bindings: Array[InputBinding] = []
## 手势配置（可为 null）
var gesture_profile: InputGestureProfile = null


func _init(p_action_id: String, p_type: int = ActionType.BINARY) -> void:
	action_id = p_action_id
	action_type = p_type


# ============================================================
# 链式配置 API
# ============================================================

## 添加键盘按键绑定。
func bind_key(p_keycode: Key, p_scale: float = 1.0, p_mode: int = InputBinding.Mode.HELD) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.KEYBOARD, p_keycode, p_scale, p_mode))
	return self

## 添加鼠标滚轮绑定。
func bind_wheel(p_button: MouseButton, p_scale: float = 1.0, p_mode: int = InputBinding.Mode.IMPULSE) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.MOUSE_WHEEL, p_button, p_scale, p_mode))
	return self

## 添加鼠标按钮绑定。
func bind_mouse(p_button: MouseButton, p_scale: float = 1.0, p_mode: int = InputBinding.Mode.IMPULSE) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.MOUSE_BUTTON, p_button, p_scale, p_mode))
	return self

## 添加手柄按钮绑定。
func bind_gamepad_button(p_button: JoyButton, p_scale: float = 1.0, p_mode: int = InputBinding.Mode.IMPULSE) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.GAMEPAD_BUTTON, p_button, p_scale, p_mode))
	return self

## 添加手柄摇杆/扳机轴绑定。
## p_negative=true 时取负半轴值（如左摇杆向左）。
func bind_gamepad_axis(p_axis: JoyAxis, p_scale: float = 1.0, p_mode: int = InputBinding.Mode.ANALOG, p_negative: bool = false) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.GAMEPAD_AXIS, p_axis, p_scale, p_mode, p_negative))
	return self

## 添加触控板双指滑动手势绑定（使用 delta.y）。
func bind_touch_pan(p_scale: float = 1.0) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.TOUCH_PAN, 0, p_scale, InputBinding.Mode.ANALOG))
	return self

## 添加触控板双指捏合手势绑定（使用 factor）。
func bind_touch_magnify(p_scale: float = 1.0) -> InputActionDef:
	bindings.append(InputBinding.new(InputBinding.Source.TOUCH_MAGNIFY, 0, p_scale, InputBinding.Mode.ANALOG))
	return self

## 设置死区。
func set_deadzone(p_val: float) -> InputActionDef: deadzone = p_val; return self
## 设置灵敏度乘数。
func set_sensitivity(p_val: float) -> InputActionDef: sensitivity = p_val; return self
## 设置平滑系数。
func set_smoothing(p_val: float) -> InputActionDef: smoothing = p_val; return self
## 设置合成模式。
func set_compose(p_val: int) -> InputActionDef: compose_mode = p_val; return self
## 设置设备约束。
func set_device_constraint(p_val: int) -> InputActionDef: device_constraint = p_val; return self
## 设置显示名（设置面板用）。
func set_display_name(p_val: String) -> InputActionDef: display_name = p_val; return self
## 设置分类（设置面板用）。
func set_category(p_val: String) -> InputActionDef: category = p_val; return self
## 设置是否可重绑定。
func set_rebindable(p_val: bool) -> InputActionDef: rebindable = p_val; return self
## 设置单击/双击手势。
func set_click_gesture(p_single: String, p_double: String, p_window_ms: int = 300,
	p_require_same: bool = true, p_drag_cancel: float = 8.0) -> InputActionDef:
	gesture_profile = InputGestureProfile.new()
	gesture_profile.enable_click_gesture = true
	gesture_profile.single_action_id = p_single
	gesture_profile.double_action_id = p_double
	gesture_profile.double_click_window_ms = p_window_ms
	gesture_profile.require_same_target = p_require_same
	gesture_profile.drag_cancel_px = p_drag_cancel
	return self
## 保存当前绑定为默认值（注册完成后调用）。
func snapshot_default_bindings() -> void:
	default_bindings.clear()
	for b in bindings:
		default_bindings.append(b.duplicate_binding())
