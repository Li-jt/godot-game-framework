# tests/unit/config/test_reference_validator.gd
extends GutTest

const VALIDATOR_PATH := "res://config/reference_validator.gd"

var _service: GF_ConfigService
var _log: GF_FakeLogService
var _fs: GF_FakeFileSystemService
var _validator_script: GDScript


func before_each() -> void:
	_log = GF_FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()
	_fs = GF_FakeFileSystemService.new()
	_service = GF_ConfigService.new()
	_service.module_name = "ConfigService"
	_service.init_module()
	_service.configure(_fs, _log)
	_service.register_defs("items", {"iron_ore": {}, "coal": {}, "wood": {}})
	_validator_script = load(VALIDATOR_PATH)


func after_each() -> void:
	_service = null; _log = null; _fs = null; _validator_script = null


func test_single_reference_valid() -> void:
	_service.register_defs("recipes", {"iron_ingot": {"result_item": "iron_ore"}})
	var errors := _check_refs("recipes", "items", "result_item", "产物")
	assert_eq(errors.size(), 0)


func test_single_reference_invalid() -> void:
	_service.register_defs("recipes", {"bad": {"result_item": "phantom"}})
	var errors := _check_refs("recipes", "items", "result_item", "产物")
	assert_eq(errors.size(), 1)
	assert_true(str(errors[0]).contains("phantom"))


func test_array_reference_all_valid() -> void:
	_service.register_defs("recipes", {"steel": {"ingredient_ids": ["iron_ore", "coal"]}})
	var errors := _check_refs("recipes", "items", "ingredient_ids", "原料")
	assert_eq(errors.size(), 0)


func test_array_reference_partial_invalid() -> void:
	_service.register_defs("recipes", {"bad": {"ingredient_ids": ["iron_ore", "mythril", "coal"]}})
	var errors := _check_refs("recipes", "items", "ingredient_ids", "原料")
	assert_eq(errors.size(), 1)
	assert_true(str(errors[0]).contains("mythril"))


func test_array_reference_empty_skipped() -> void:
	_service.register_defs("recipes", {"simple": {"ingredient_ids": []}})
	var errors := _check_refs("recipes", "items", "ingredient_ids", "原料")
	assert_eq(errors.size(), 0)


func test_dict_array_with_subfield_valid() -> void:
	_service.register_defs("recipes", {"steel": {"ingredients": [
		{"id": "iron_ore", "count": 3}, {"id": "coal", "count": 1}
	]}})
	var errors := _check_refs_with_subfield("recipes", "items", "ingredients", "id", "原料")
	assert_eq(errors.size(), 0)


func test_dict_array_with_subfield_invalid() -> void:
	_service.register_defs("recipes", {"bad": {"ingredients": [
		{"id": "iron_ore", "count": 3}, {"id": "unobtanium", "count": 1}
	]}})
	var errors := _check_refs_with_subfield("recipes", "items", "ingredients", "id", "原料")
	assert_eq(errors.size(), 1)
	assert_true(str(errors[0]).contains("unobtanium"))


func test_null_reference_skipped() -> void:
	_service.register_defs("recipes", {"none": {"optional_item": null}})
	var errors := _check_refs("recipes", "items", "optional_item", "可选")
	assert_eq(errors.size(), 0)


func test_missing_field_skipped() -> void:
	_service.register_defs("recipes", {"empty": {"name": "no_ref"}})
	var errors := _check_refs("recipes", "items", "result_item", "产物")
	assert_eq(errors.size(), 0)


func test_missing_config_reports_error() -> void:
	var v = _validator_script.new()
	v.type_key = "recipes"
	v.target_type = "items"
	v.source_field = "result_item"
	var errors: Array[String] = v.validate({"r1": {"result_item": "iron_ore"}})
	assert_eq(errors.size(), 1)
	assert_true(str(errors[0]).contains("ConfigService"))


func test_multiple_sources_each_with_errors() -> void:
	_service.register_defs("recipes", {
		"r1": {"ingredient_ids": ["bad_a"]},
		"r2": {"ingredient_ids": ["bad_b"]},
	})
	var errors := _check_refs("recipes", "items", "ingredient_ids", "原料")
	assert_eq(errors.size(), 2)


func test_validate_all_catches_reference_errors() -> void:
	var v = _make_ref_validator("recipes", "items", "result_item", "产物")
	_service.register_validator(v)
	_service.register_defs("recipes", {"bad": {"result_item": "phantom"}})
	var result := _service.validate_all()
	assert_true(result.is_fail())
	var all_errors: Array = result.error.context["errors"]
	var found := false
	for err in all_errors:
		if str(err).contains("phantom"):
			found = true
			break
	assert_true(found)


func test_hot_reload_also_validates_references() -> void:
	# 热重载后的 validate_type 也应该捕获引用错误
	_fs.preset_json("res://recipes.json", {"bad": {"result_item": "phantom"}})
	_service.load_json("recipes", "res://recipes.json")
	var v = _make_ref_validator("recipes", "items", "result_item", "产物")
	_service.register_validator(v)
	var result := _service.validate_type("recipes")
	assert_true(result.is_fail())


func _check_refs(p_source: String, p_target: String, p_field: String, p_label: String) -> Array[String]:
	var v = _make_ref_validator(p_source, p_target, p_field, p_label)
	return v.validate(_service.get_all(p_source))


func _check_refs_with_subfield(p_source: String, p_target: String, p_field: String, p_subfield: String, p_label: String) -> Array[String]:
	var v = _make_ref_validator(p_source, p_target, p_field, p_label)
	v.ref_subfield = p_subfield
	return v.validate(_service.get_all(p_source))


func _make_ref_validator(p_source: String, p_target: String, p_field: String, p_label: String):
	var v = _validator_script.new()
	v.type_key = p_source
	v.target_type = p_target
	v.source_field = p_field
	v.reference_label = p_label
	v.set_config(_service)
	return v
