## AppFlow
## 应用流程状态机。管理 App 级逻辑状态（非 Godot SceneTree 状态）。
## 所有状态切换通过此服务完成，禁止各模块自行判断"当前在哪个界面"。
##
## 状态流转：
##   BOOT → MAIN_MENU → LOADING → IN_GAME ⇄ PAUSE
##                ↑                    ↓
##                └────────────────────┘
##
## 每次状态切换通过 EventBus 发布 "flow_state_changed" 事件。
class_name AppFlow
extends ModuleLifecycle

## 流程状态——StringName 常量 + 动态注册。
const STATE_BOOT: StringName = &"boot"
const STATE_MAIN_MENU: StringName = &"main_menu"
const STATE_LOADING: StringName = &"loading"
const STATE_IN_GAME: StringName = &"in_game"
const STATE_PAUSE: StringName = &"pause"

var current_state: StringName = STATE_BOOT
var previous_state: StringName = STATE_BOOT
var current_payload: Dictionary = {}
var _event_bus: EventBus = null

## 状态转换表——基于 StringName 的字典。
var _transitions: Dictionary = {
	STATE_BOOT:       { "from": ["*"],           "to": [STATE_MAIN_MENU] },
	STATE_MAIN_MENU:  { "from": [STATE_BOOT],     "to": [STATE_LOADING] },
	STATE_LOADING:    { "from": [STATE_MAIN_MENU, STATE_IN_GAME], "to": [STATE_IN_GAME] },
	STATE_IN_GAME:    { "from": [STATE_LOADING, STATE_PAUSE], "to": [STATE_PAUSE, STATE_LOADING, STATE_MAIN_MENU] },
	STATE_PAUSE:      { "from": [STATE_IN_GAME],  "to": [STATE_IN_GAME] },
}


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_event_bus: EventBus) -> OperationResult:
	if p_event_bus == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: event_bus 不能为 null", module_name)
	_event_bus = p_event_bus
	return OperationResult.ok()


# ============================================================
# 状态切换
# ============================================================

## 切换到指定状态。无效状态或同状态切换会被拒绝。
## p_payload 可选，携带 slot_id / world_id 等上下文数据。
func transition_to(p_target: StringName, p_payload: Dictionary = {}) -> OperationResult:
	if p_target == current_state:
		return OperationResult.ok()

	if not _transitions.has(p_target):
		return OperationResult.fail(
			OperationResult.ERR_INVALID_ARGUMENT,
			"未知状态: %s" % p_target,
			module_name
		)

	var allowed_from: Array = _transitions[p_target]["from"]
	if not allowed_from.has(current_state) and allowed_from[0] != "*":
		return OperationResult.fail(
			OperationResult.ERR_PRECONDITION,
			"无效的状态切换: %s → %s" % [current_state, p_target],
			module_name
		)

	previous_state = current_state
	current_state = p_target
	current_payload = p_payload

	if _event_bus != null:
		_event_bus.publish("flow_state_changed", {
			"from": previous_state,
			"to": current_state,
			"payload": current_payload,
		})

	return OperationResult.ok()


## 动态注册新的流程状态。Mod 使用。
func register_state(p_state: StringName, p_valid_from: Array[StringName], p_valid_to: Array[StringName]) -> void:
	_transitions[p_state] = {"from": p_valid_from, "to": p_valid_to}


## 获取当前状态携带的 payload
func get_current_payload() -> Dictionary:
	return current_payload


## 当前状态
func get_state() -> StringName:
	return current_state


## 是否在指定状态
func is_in_state(p_state: StringName) -> bool:
	return current_state == p_state


## 上一状态
func get_previous_state() -> StringName:
	return previous_state


# ============================================================
# 便捷切换方法
# ============================================================

func to_main_menu() -> OperationResult:
	return transition_to(STATE_MAIN_MENU)


func to_loading() -> OperationResult:
	return transition_to(STATE_LOADING)


func to_in_game() -> OperationResult:
	return transition_to(STATE_IN_GAME)


func to_pause() -> OperationResult:
	return transition_to(STATE_PAUSE)


func resume_from_pause() -> OperationResult:
	if current_state != STATE_PAUSE:
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "当前不在暂停状态", module_name)
	return transition_to(STATE_IN_GAME)
