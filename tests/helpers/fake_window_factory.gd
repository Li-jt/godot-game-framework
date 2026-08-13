# tests/helpers/fake_window_factory.gd
## 测试用 GF_SceneFactory 模拟类：create 返回 GF_FakeWindowPanel。
class_name GF_FakeWindowFactory
extends GF_SceneFactory


func create(_p_path: String, _p_data: Dictionary = {}) -> GF_OperationResult:
	return GF_OperationResult.ok(GF_FakeWindowPanel.new())
