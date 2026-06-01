## InputBindingConfig — 按键配置持久化 Resource（v4.0）。
class_name InputBindingConfig
extends Resource

@export var version: int = 1
## { action_id → { "primary": BindingDict, "secondary": BindingDict } }
@export var actions: Dictionary = {}


func set_action_slots(p_action_id: String, p_primary: Dictionary, p_secondary: Dictionary) -> void:
	actions[p_action_id] = {"primary": p_primary, "secondary": p_secondary}


func get_action_slots(p_action_id: String) -> Dictionary:
	return actions.get(p_action_id, {})


func save_to_file(p_path: String) -> bool:
	var result := ResourceSaver.save(self, p_path)
	return result == OK


static func load_from_file(p_path: String) -> InputBindingConfig:
	if not ResourceLoader.exists(p_path):
		return null
	return ResourceLoader.load(p_path) as InputBindingConfig


## 从动作定义创建默认配置。
static func from_defs(p_defs: Dictionary) -> InputBindingConfig:
	var config := InputBindingConfig.new()
	for action_id in p_defs.keys():
		var def: InputActionDef = p_defs[action_id]
		var primary := {}
		var secondary := {}
		for b in def.default_bindings:
			var d := b.to_dict()
			if b.slot == InputBinding.Slot.PRIMARY:
				primary = d
			else:
				secondary = d
		config.actions[action_id] = {"primary": primary, "secondary": secondary}
	return config


## 应用配置到动作定义。
func apply_to_defs(p_defs: Dictionary) -> void:
	for action_id in actions.keys():
		var def: InputActionDef = p_defs.get(action_id, null)
		if def == null: continue
		var slots: Dictionary = actions[action_id]
		def.bindings.clear()
		for slot_key in ["primary", "secondary"]:
			var data: Dictionary = slots.get(slot_key, {})
			if data.is_empty(): continue
			var b := InputBinding.from_dict(data)
			def.bindings.append(b)
