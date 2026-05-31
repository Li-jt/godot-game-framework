## InputActionDef — 输入动作定义。
## 描述一个逻辑动作的类型（二进制/轴）和默认设备绑定。
## 由 Game 层注册到 InputService，运行时通过 InputService 统一查询。
class_name InputActionDef
extends RefCounted

## 动作类型
enum ActionType {
	BINARY,  ## 按下/释放（跳跃、确认、开枪）
	AXIS,    ## 连续轴（滚轮、摇杆、扳机）
}

## 逻辑动作 ID（如 "camera_zoom", "move"）
var action_id: String = ""
## 动作类型
var action_type: int = ActionType.BINARY
## Godot InputMap 对应的 action 名称（多个物理输入映射到同一个逻辑动作）
var input_map_actions: Array[String] = []
## 轴灵敏度（仅 AXIS 类型）
var axis_sensitivity: float = 1.0
## 轴死区（仅 AXIS 类型，绝对值小于此值视为 0）
var axis_deadzone: float = 0.1


func _init(p_action_id: String, p_type: int = ActionType.BINARY,
	p_input_map_actions: Array[String] = [],
	p_sensitivity: float = 1.0, p_deadzone: float = 0.1) -> void:
	action_id = p_action_id
	action_type = p_type
	input_map_actions = p_input_map_actions.duplicate()
	axis_sensitivity = p_sensitivity
	axis_deadzone = p_deadzone


## 是否为轴类型。
func is_axis() -> bool:
	return action_type == ActionType.AXIS


## 是否为二进制类型。
func is_binary() -> bool:
	return action_type == ActionType.BINARY
