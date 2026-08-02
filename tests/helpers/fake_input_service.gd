# tests/helpers/fake_input_service.gd
## 测试用 GF_InputService 模拟类。
class_name GF_FakeInputService
extends GF_InputService

func set_game_input_blocker(_p_cb: Callable) -> void:
	pass

func push_context(_ctx: Variant) -> void:
	pass

func pop_context() -> void:
	pass
