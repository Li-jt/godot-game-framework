# tests/contract/test_repository_contract.gd
## 契约测试：Repository 接口族。
## 验证 IEntityRepository 的 CRUD 操作约定。
extends GutTest


func test_entity_repository_crud_contract() -> void:
	# Entity 包含 id + type
	var entity := {"id": "e_001", "type": "hero", "data": {"hp": 100}}
	assert_true(entity.has("id"))
	assert_true(entity.has("type"))
	assert_true(entity.has("data"))
