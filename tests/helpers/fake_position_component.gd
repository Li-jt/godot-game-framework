# tests/helpers/fake_position_component.gd
## 测试辅助：带包围盒的 Game 层组件（空间索引测试用 marker）。
class_name FakePositionComponent
extends GF_EcsComponentBase

var rect: Rect2 = Rect2()


func get_component_type() -> StringName:
	return &"FakePosition"


func serialize() -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}


func deserialize(p_data: Dictionary) -> void:
	rect = Rect2(p_data.get("x", 0.0), p_data.get("y", 0.0), p_data.get("w", 0.0), p_data.get("h", 0.0))
