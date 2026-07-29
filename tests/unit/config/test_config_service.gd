# tests/unit/config/test_config_service.gd
extends GutTest

var _service: ConfigService
var _log: FakeLogService


func before_each() -> void:
	_log = FakeLogService.new()
	_log.module_name = "FakeLog"
	_log.init_module()
	_service = ConfigService.new()
	_service.module_name = "ConfigService"
	_service.init_module()


func after_each() -> void:
	_service = null
	_log = null


func test_register_defs_stores_by_type_and_id() -> void:
	var defs := {"sword": {"damage": 10}, "axe": {"damage": 15}}
	_service.register_defs("weapons", defs)
	assert_true(_service.has_def("weapons", "sword"))
	assert_true(_service.has_def("weapons", "axe"))


func test_get_def_returns_correct() -> void:
	var defs := {"sword": {"damage": 25}}
	_service.register_defs("weapons", defs)
	var result = _service.get_def("weapons", "sword")
	assert_eq(result, {"damage": 25})


func test_get_def_returns_null_for_unknown() -> void:
	assert_null(_service.get_def("nonexistent", "unknown"))


func test_has_def_checks_existence() -> void:
	assert_false(_service.has_def("weapons", "sword"))
	_service.register_defs("weapons", {"sword": {}})
	assert_true(_service.has_def("weapons", "sword"))


func test_get_all_returns_all_of_type() -> void:
	_service.register_defs("weapons", {"a": {}, "b": {}, "c": {}})
	var all: Dictionary = _service.get_all("weapons")
	assert_eq(all.size(), 3)
