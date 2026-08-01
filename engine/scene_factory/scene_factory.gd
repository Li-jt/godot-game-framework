## GF_SceneFactory
## 统一场景/节点实例化工厂。封装 PackedScene 加载与 instantiate()。
## 所有模块的场景实例化、UI 面板创建必须通过此服务，禁止直接调用 .instantiate()。
##
## 使用方式：
##   [codeblock]
##   var result := factory.create("ui/hud_panel.tscn")
##   if result.is_ok():
##       add_child(result.data)
##   [/codeblock]
class_name GF_SceneFactory
extends GF_ModuleLifecycle

var _asset_loading: GF_AssetLoadingService = null
var _log: GF_LogService = null



func _set_bootstrap(p_bs) -> void:
	_bootstrap = p_bs
	if _bootstrap.service(GF_AssetLoadingService) == null:
		_bootstrap.register(GF_AssetLoadingService.new())


func dependencies() -> Array:
	return [GF_AssetLoadingService, GF_LogService]

func configure() -> GF_OperationResult:
	_asset_loading = _bootstrap.service(GF_AssetLoadingService) as GF_AssetLoadingService
	_log = _bootstrap.service(GF_LogService) as GF_LogService
	return GF_OperationResult.ok()


# ============================================================
# 公开方法
# ============================================================

## 加载场景并实例化根节点
## p_init_data 可选，传入后调用节点的 _on_factory_init(data) 钩子（如有）
func create(p_scene_path: String, p_init_data: Dictionary = {}) -> GF_OperationResult:
	var load_result := _asset_loading.load_scene(p_scene_path)
	if load_result.is_fail():
		return load_result

	var scene: PackedScene = load_result.data
	var node := scene.instantiate()
	if node == null:
		_log.error("GF_SceneFactory", "实例化失败: %s" % p_scene_path)
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"场景实例化失败: %s" % p_scene_path,
			module_name
		)

	# 调用初始化钩子
	if not p_init_data.is_empty():
		if node.has_method("_on_factory_init"):
			node._on_factory_init(p_init_data)

	_log.debug("GF_SceneFactory", "已创建节点: %s" % p_scene_path)
	return GF_OperationResult.ok(node)


## 创建场景并挂载到父节点
func create_and_add(p_scene_path: String, p_parent: Node, p_init_data: Dictionary = {}) -> GF_OperationResult:
	var result := create(p_scene_path, p_init_data)
	if result.is_fail():
		return result

	var node: Node = result.data
	p_parent.add_child(node)
	return GF_OperationResult.ok(node)


## 用已加载的 PackedScene 直接实例化（避免重复加载）
func instantiate(p_scene: PackedScene, p_init_data: Dictionary = {}) -> GF_OperationResult:
	var node := p_scene.instantiate()
	if node == null:
		_log.error("GF_SceneFactory", "从已加载场景实例化失败")
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"场景实例化失败",
			module_name
		)

	if not p_init_data.is_empty():
		if node.has_method("_on_factory_init"):
			node._on_factory_init(p_init_data)

	return GF_OperationResult.ok(node)
