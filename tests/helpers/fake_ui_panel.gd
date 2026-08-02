# tests/helpers/fake_ui_panel.gd
## 测试用 GF_UIPanel 模拟类。
class_name GF_FakeUIPanel
extends GF_UIPanel

func _init() -> void:
	panel_name = ""
	_focus_mode = Control.FOCUS_ALL
	_default_focus_path = NodePath()

func set_focus_config(p_mode: Control.FocusMode, _p_default_focus: NodePath) -> void:
	_focus_mode = p_mode

func _on_open(_p_data: Dictionary) -> void:
	pass

func _on_close() -> void:
	pass

func _on_hide() -> void:
	pass

func _on_reopen(_p_data: Dictionary) -> void:
	pass

func is_pointer_over_game_input_blocking_area(_p_pos: Vector2) -> bool:
	return false
