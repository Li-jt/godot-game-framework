# tests/unit/core/test_content_def_registry.gd
extends GutTest

var _registry: ContentDefRegistry


func before_each() -> void:
	_registry = ContentDefRegistry.new()


func after_each() -> void:
	_registry = null


func test_register_module_stores_by_name() -> void:
	var data = {"key": "value"}
	_registry.register_module(&"test_module", data)
	var retrieved = _registry.module(&"test_module")
	assert_eq(retrieved, data)


func test_module_returns_null_for_unknown() -> void:
	assert_null(_registry.module(&"nonexistent"))


func test_has_module_checks_existence() -> void:
	assert_false(_registry.has_module(&"test_module"))
	_registry.register_module(&"test_module", {})
	assert_true(_registry.has_module(&"test_module"))


func test_register_duplicate_overwrites() -> void:
	_registry.register_module(&"test_module", {"version": 1})
	_registry.register_module(&"test_module", {"version": 2})
	var mod = _registry.module(&"test_module")
	assert_eq(mod.version, 2)


func test_unregister_module_removes() -> void:
	_registry.register_module(&"test_module", {})
	_registry.unregister_module(&"test_module")
	assert_false(_registry.has_module(&"test_module"))


func test_unregister_nonexistent_no_error() -> void:
	_registry.unregister_module(&"nonexistent")


func test_clear_removes_all() -> void:
	_registry.register_module(&"a", {})
	_registry.register_module(&"b", {})
	_registry.register_module(&"c", {})
	_registry.clear()
	assert_false(_registry.has_module(&"a"))
	assert_false(_registry.has_module(&"b"))
	assert_false(_registry.has_module(&"c"))


func test_module_names_empty_initially() -> void:
	var names = _registry.module_names()
	assert_eq(names.size(), 0)


func test_module_names_returns_all() -> void:
	_registry.register_module(&"a", {})
	_registry.register_module(&"b", {})
	var names = _registry.module_names()
	assert_eq(names.size(), 2)
