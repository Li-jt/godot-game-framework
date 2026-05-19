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

enum State {
	BOOT,         # 启动中
	MAIN_MENU,    # 主菜单
	LOADING,      # 加载中（读档/创建世界）
	IN_GAME,      # 游戏中
	PAUSE,        # 暂停
}

var current_state: State = State.BOOT
var previous_state: State = State.BOOT
var current_payload: Dictionary = {}
var _event_bus: EventBus = null


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
func transition_to(p_target: State, p_payload: Dictionary = {}) -> OperationResult:
	if p_target == current_state:
		return OperationResult.ok()

	if not _is_valid_transition(current_state, p_target):
		return OperationResult.fail(
			OperationResult.ERR_PRECONDITION,
			"无效的状态切换: %s → %s" % [_state_name(current_state), _state_name(p_target)],
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


## 获取当前状态携带的 payload
func get_current_payload() -> Dictionary:
	return current_payload


## 当前状态
func get_state() -> State:
	return current_state


## 是否在指定状态
func is_in_state(p_state: State) -> bool:
	return current_state == p_state


## 上一状态
func get_previous_state() -> State:
	return previous_state


# ============================================================
# 便捷切换方法
# ============================================================

func to_main_menu() -> OperationResult:
	return transition_to(State.MAIN_MENU)


func to_loading() -> OperationResult:
	return transition_to(State.LOADING)


func to_in_game() -> OperationResult:
	return transition_to(State.IN_GAME)


func to_pause() -> OperationResult:
	return transition_to(State.PAUSE)


func resume_from_pause() -> OperationResult:
	if current_state != State.PAUSE:
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "当前不在暂停状态", module_name)
	return transition_to(State.IN_GAME)


# ============================================================
# 内部
# ============================================================

func _is_valid_transition(p_from: State, p_to: State) -> bool:
	match p_from:
		State.BOOT:
			return p_to == State.MAIN_MENU 
		State.MAIN_MENU:
			return p_to == State.LOADING
		State.LOADING:
			return p_to == State.IN_GAME
		State.IN_GAME:
			return p_to == State.PAUSE or p_to == State.LOADING or p_to == State.MAIN_MENU
		State.PAUSE:
			return p_to == State.IN_GAME
		_:
			return false


func _state_name(p_state: State) -> String:
	match p_state:
		State.BOOT:       return "BOOT"
		State.MAIN_MENU:  return "MAIN_MENU"
		State.LOADING:    return "LOADING"
		State.IN_GAME:    return "IN_GAME"
		State.PAUSE:      return "PAUSE"
		_: return "UNKNOWN"
