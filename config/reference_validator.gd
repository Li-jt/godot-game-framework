## GF_ReferenceValidator — Def 间引用完整性校验器。
##
## 检查 source_type 的 defs 中某个字段引用的 ID 是否在 target_type 中真实存在。
## 支持单引用（String）、数组引用（Array[String]）、以及 Dict 数组中的嵌套引用。
##
## [br]使用示例：
## [codeblock]
## # recipes.json 的 ingredient_ids 引用了 items.json 中的 ID
## var v := GF_ReferenceValidator.new()
## v.type_key = "recipes"
## v.target_type = "items"
## v.source_field = "ingredient_ids"
## v.reference_label = "原料"
## v.set_config(config_service)
## config_service.register_validator(v)
## [/codeblock]
class_name GF_ReferenceValidator
extends GF_DefValidator

## 被引用的目标类型 key（如 "items"、"buildings"）。
var target_type: String = ""

## source def 中存放引用 ID 的字段名。支持点号分隔的嵌套路径。
var source_field: String = ""

## 如果 source_field 的值是 Dict 数组，此字段指定每个 Dict 中哪个 key 是引用 ID。
var ref_subfield: String = ""

## 引用的语义描述，用于错误消息（如 "原料"、"前置建筑"）。
var reference_label: String = "引用"

var _config: GF_ConfigService = null


## 注入 ConfigService，用于跨类型查询目标定义。
func set_config(p_config: GF_ConfigService) -> void:
	_config = p_config


## 校验 source_type 的所有定义，返回引用不存在的错误列表。
func validate(p_defs: Dictionary) -> Array[String]:
	if _config == null:
		return ["GF_ReferenceValidator [%s]: 未注入 ConfigService，跳过引用检查" % type_key]

	var target_defs: Dictionary = _config.get_all(target_type)
	var errors: Array[String] = []

	for source_id in p_defs.keys():
		var raw = _get_nested(p_defs[source_id], source_field)
		if raw == null:
			continue

		var ref_ids: Array[String] = _extract_ref_ids(raw)
		for ref_id in ref_ids:
			if not target_defs.has(ref_id):
				errors.append("%s '%s' 引用的%s '%s' 在 '%s' 中不存在" % [type_key, source_id, reference_label, ref_id, target_type])

	return errors


func _extract_ref_ids(p_raw) -> Array[String]:
	var result: Array[String] = []

	if typeof(p_raw) == TYPE_ARRAY:
		var arr: Array = p_raw as Array
		for elem in arr:
			if ref_subfield.is_empty():
				var id_str: String = str(elem)
				if not id_str.is_empty():
					result.append(id_str)
			elif typeof(elem) == TYPE_DICTIONARY:
				var d: Dictionary = elem as Dictionary
				if d.has(ref_subfield):
					var id_str: String = str(d[ref_subfield])
					if not id_str.is_empty():
						result.append(id_str)
	elif typeof(p_raw) == TYPE_STRING:
		var id_str: String = str(p_raw)
		if not id_str.is_empty():
			result.append(id_str)

	return result


func _get_nested(p_dict: Dictionary, p_path: String):
	if p_path.is_empty():
		return null
	var parts: PackedStringArray = p_path.split(".")
	var current: Dictionary = p_dict
	for i in range(parts.size()):
		var key: String = parts[i]
		if i == parts.size() - 1:
			return current.get(key, null)
		var next = current.get(key, null)
		if typeof(next) != TYPE_DICTIONARY:
			return null
		current = next as Dictionary
	return null
