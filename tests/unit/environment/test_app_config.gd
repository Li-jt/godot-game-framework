# tests/unit/environment/test_app_config.gd
## AppConfig 单元测试。
## 配置加载、环境变量覆盖、校验。
extends GutTest

var _config: AppConfig


func before_each() -> void:
	_config = AppConfig.new()


func after_each() -> void:
	_config = null


func test_default_config_not_null() -> void:
	assert_not_null(_config.resource)
	assert_not_null(_config.save)
	assert_not_null(_config.logging)


func test_resource_base_path_default() -> void:
	assert_ne(_config.resource.base_path, "")


func test_save_root_default() -> void:
	assert_ne(_config.save.local_save_root, "")
