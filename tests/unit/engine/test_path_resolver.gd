# tests/unit/engine/test_path_resolver.gd
## GF_PathResolver 单元测试。
## 路径解析：res:// / user:// 前缀、路径标准化、越界检查。
extends GutTest

var _resolver: GF_PathResolver


func before_each() -> void:
	_resolver = GF_PathResolver.new()


func after_each() -> void:
	_resolver = null


func test_configure_sets_paths() -> void:
	var result := _resolver.configure("content", "saves", "cache", "logs")
	assert_true(result.is_ok())
	assert_eq(_resolver.resource_root, "res://content/")
	assert_eq(_resolver.save_root, "user://saves/")


func test_configure_rejects_empty_arguments() -> void:
	var result := _resolver.configure("", "saves", "cache", "logs")
	assert_true(result.is_fail())
	assert_eq(result.status_code, GF_OperationResult.ERR_BAD_REQUEST)


func test_normalize_unifies_slashes() -> void:
	var result := GF_PathResolver.normalize("path//to//file.text")
	assert_eq(result, "path/to/file.text")


func test_normalize_strips_dotslash() -> void:
	var result := GF_PathResolver.normalize("./path/./to/file")
	assert_eq(result, "path/to/file")


func test_ensure_under_root_allows_valid_path() -> void:
	var result := GF_PathResolver.ensure_under_root("res://data/file.json", "res://data")
	assert_true(result.is_ok())


func test_ensure_under_root_blocks_traversal() -> void:
	var result := GF_PathResolver.ensure_under_root("res://data/../secrets.txt", "res://data")
	assert_true(result.is_fail())


func test_get_config_root() -> void:
	_resolver.configure("content", "saves", "cache", "logs")
	assert_eq(_resolver.get_config_root(), "res://config/")


func test_get_cache_root() -> void:
	_resolver.configure("content", "saves", "cache", "logs")
	assert_eq(_resolver.get_cache_root(), "user://cache/")
