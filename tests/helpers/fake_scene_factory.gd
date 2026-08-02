# tests/helpers/fake_scene_factory.gd
## 测试用 GF_SceneFactory 模拟类。
class_name GF_FakeSceneFactory
extends GF_SceneFactory

func create(_p_path: String, _p_data: Dictionary = {}) -> GF_OperationResult:
	return GF_OperationResult.ok(GF_FakeUIPanel.new())
