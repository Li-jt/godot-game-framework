# tests/unit/engine/test_input_adapter.gd
## GF_InputAdapter 单元测试。
## 统一输入适配层：block/unblock、动作查询、轴读取。
extends GutTest

var _adapter: GF_InputAdapter


func before_each() -> void:
	_adapter = GF_InputAdapter.new()


func after_each() -> void:
	_adapter = null


func test_block_prevents_action_pressed() -> void:
	_adapter.block()
	assert_false(_adapter.is_action_pressed("ui_accept"))


func test_block_prevents_action_just_pressed() -> void:
	_adapter.block()
	assert_false(_adapter.is_action_just_pressed("ui_accept"))


func test_block_prevents_action_just_released() -> void:
	_adapter.block()
	assert_false(_adapter.is_action_just_released("ui_accept"))


func test_block_prevents_action_strength() -> void:
	_adapter.block()
	assert_eq(_adapter.get_action_strength("ui_accept"), 0.0)


func test_block_prevents_vector() -> void:
	_adapter.block()
	assert_eq(_adapter.get_vector("move_left", "move_right", "move_up", "move_down"), Vector2.ZERO)


func test_block_prevents_read_axis() -> void:
	_adapter.block()
	assert_eq(_adapter.read_axis(["ui_accept"]), 0.0)


func test_unblock_restores() -> void:
	_adapter.block()
	_adapter.unblock()
	assert_false(_adapter.blocked)


func test_unblock_then_block_again() -> void:
	_adapter.block()
	_adapter.unblock()
	_adapter.block()
	assert_true(_adapter.blocked)
