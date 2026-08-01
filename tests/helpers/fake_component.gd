# tests/helpers/fake_component.gd
## 测试辅助：模拟 Game 层定义的组件类。
## 继承 GF_EcsComponentBase，支持工厂自动发现。
class_name FakeComponent
extends GF_EcsComponentBase

var hp: int = 100
var max_hp: int = 100


func get_component_type() -> StringName:
	return &"FakeHealth"


func serialize() -> Dictionary:
	return {"hp": hp, "max_hp": max_hp}


func deserialize(p_data: Dictionary) -> void:
	hp = p_data.get("hp", 100)
	max_hp = p_data.get("max_hp", 100)
