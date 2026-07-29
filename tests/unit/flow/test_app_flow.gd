# tests/unit/flow/test_app_flow.gd
extends GutTest

var _flow: AppFlow


func before_each() -> void:
	_flow = AppFlow.new()
	_flow.module_name = "AppFlow"
	_flow.init_module()


func after_each() -> void:
	_flow = null


func test_transition_to_valid_state() -> void:
	# BOOT → MAIN_MENU 是合法过渡
	var result := _flow.transition_to(AppFlow.STATE_MAIN_MENU)
	assert_true(result.is_ok())
	assert_eq(_flow.get_state(), AppFlow.STATE_MAIN_MENU)


func test_transition_to_unknown_state() -> void:
	var result := _flow.transition_to(&"nonexistent_state")
	assert_true(result.is_fail())


func test_same_state_noop() -> void:
	_flow.transition_to(AppFlow.STATE_MAIN_MENU)
	var result := _flow.transition_to(AppFlow.STATE_MAIN_MENU)
	assert_true(result.is_ok())


func test_register_state_adds_to_table() -> void:
	_flow.register_state(&"playing", [AppFlow.STATE_MAIN_MENU], [AppFlow.STATE_PAUSE])
	# 注册后 transition 应该可用（从 MAIN_MENU → playing）
	_flow.transition_to(AppFlow.STATE_MAIN_MENU)
	var result := _flow.transition_to(&"playing")
	assert_true(result.is_ok())


func test_transition_publishes_event() -> void:
	var event_bus := EventBus.new()
	event_bus.module_name = "TestEventBus"
	event_bus.init_module()
	_flow.configure(event_bus)

	var received := false
	event_bus.subscribe("flow_state_changed", func(p_data):
		received = true
	)
	_flow.transition_to(AppFlow.STATE_MAIN_MENU)
	assert_true(received)
	event_bus.dispose_module()


func test_initial_state_is_boot() -> void:
	assert_eq(_flow.get_state(), AppFlow.STATE_BOOT)
