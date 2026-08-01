## GF_SceneHost
## 场景宿主。管理相机、UI 层级和场景切换。
##
## 节点树可通过两种方式提供：
##   1. @export 注入：用户在编辑器里建好节点，拖到 SceneHost 的导出变量槽位
##   2. 代码默认：什么都不设，框架在 _ready() 中自动建一棵默认树
##
## 默认场景树：
##   GF_SceneHost
##   ├── WorldMount (Node2D)
##   ├── GameCamera (Camera2D)
##   └── UiCanvas (CanvasLayer)
##       └── UIRoot (Control)
##           ├── HudLayer
##           ├── ScreenLayer
##           ├── PopupLayer
##           ├── TooltipLayer
##           ├── SystemLayer
##           └── DebugLayer
class_name GF_SceneHost
extends Node

# ============================================================
# @export — 用户可在编辑器注入，不填则框架自动创建
# ============================================================

@export var world_mount: Node2D
@export var game_camera: Camera2D
@export var ui_canvas: CanvasLayer
@export var ui_root: Control

@export var hud_layer: Control
@export var screen_layer: Control
@export var popup_layer: Control
@export var tooltip_layer: Control
@export var system_layer: Control
@export var debug_layer: Control


# ============================================================
# 内部状态
# ============================================================

var _bootstrap = null
var _scene_factory: GF_SceneFactory = null
var _log: GF_LogService = null
var _ui_layers: Dictionary = {}
var _auto_built: bool = false

## 世界根节点引用（兼容旧名 world_root）
var world_root: Node2D:
	get: return world_mount

var _world_context = null


# ============================================================
# 生命周期
# ============================================================

func _set_bootstrap(p_bs) -> void:
	_bootstrap = p_bs


func dependencies() -> Array:
	return [GF_SceneFactory, GF_LogService]


func configure() -> GF_OperationResult:
	_scene_factory = _bootstrap.service(GF_SceneFactory) as GF_SceneFactory
	_log = _bootstrap.service(GF_LogService) as GF_LogService
	return GF_OperationResult.ok()


func _ready() -> void:
	_build_default_tree()


## 构建默认节点树。如果用户已通过 @export 注入则跳过对应节点。
func _build_default_tree() -> void:
	if _auto_built:
		return
	_auto_built = true

	if world_mount == null:
		world_mount = _add_child_node(Node2D.new(), "WorldMount")

	if game_camera == null:
		game_camera = _add_child_node(Camera2D.new(), "GameCamera")
		game_camera.position = Vector2(640, 360)
	game_camera.enabled = true
	game_camera.make_current()

	if ui_canvas == null:
		ui_canvas = _add_child_node(CanvasLayer.new(), "UiCanvas")
		ui_canvas.layer = 100

	if ui_root == null:
		ui_root = _make_full_rect("UIRoot")
		ui_canvas.add_child(ui_root)

	_ensure_layer(&"hud",     hud_layer,     "HudLayer")
	_ensure_layer(&"screen",  screen_layer,  "ScreenLayer")
	_ensure_layer(&"popup",   popup_layer,   "PopupLayer")
	_ensure_layer(&"tooltip", tooltip_layer, "TooltipLayer")
	_ensure_layer(&"system",  system_layer,  "SystemLayer")
	_ensure_layer(&"debug",   debug_layer,   "DebugLayer")


func _ensure_layer(p_kind: StringName, p_exported: Control, p_default_name: String) -> void:
	var layer := p_exported
	if layer == null:
		layer = _make_full_rect(p_default_name)
		ui_root.add_child(layer)
	_ui_layers[p_kind] = layer
	match p_kind:
		&"hud":     hud_layer = layer
		&"screen":  screen_layer = layer
		&"popup":   popup_layer = layer
		&"tooltip": tooltip_layer = layer
		&"system":  system_layer = layer
		&"debug":   debug_layer = layer


func _add_child_node(p_node: Node, p_name: String) -> Node:
	p_node.name = p_name
	add_child(p_node)
	return p_node


func _make_full_rect(p_name: String) -> Control:
	var c := Control.new()
	c.name = p_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func is_runtime_ready() -> bool:
	return world_mount != null and ui_root != null and hud_layer != null


# ============================================================
# 自定义层级
# ============================================================

## 注册自定义 UI 层级。p_layer 必须是 ui_root 的子节点，按 add_child 顺序决定 z-order。
func register_ui_layer(p_kind: StringName, p_layer: Control) -> GF_OperationResult:
	if _ui_layers.has(p_kind):
		return GF_OperationResult.fail(GF_OperationResult.ERR_CONFLICT, "层级已存在: %s" % p_kind, "GF_SceneHost")
	if p_layer == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "layer 不能为 null", "GF_SceneHost")
	_ui_layers[p_kind] = p_layer
	return GF_OperationResult.ok()


# ============================================================
# 世界上下文
# ============================================================

func set_world_context(p_bs) -> void:
	_world_context = p_bs


# ============================================================
# 挂载点获取
# ============================================================

func get_world_root() -> Node2D:
	return world_mount


func get_camera() -> Camera2D:
	return game_camera


func get_ui_root() -> Control:
	return ui_root


func get_ui_canvas() -> CanvasLayer:
	return ui_canvas


func get_ui_layer(p_kind: StringName) -> Control:
	var layer: Control = _ui_layers.get(p_kind, null)
	if layer != null:
		return layer
	# 回退：按内建常量匹配
	match p_kind:
		GF_UIPanelDef.KIND_HUD:     return hud_layer
		GF_UIPanelDef.KIND_SCREEN:  return screen_layer
		GF_UIPanelDef.KIND_POPUP:   return popup_layer
		GF_UIPanelDef.KIND_TOOLTIP: return tooltip_layer
		GF_UIPanelDef.KIND_SYSTEM:  return system_layer
		GF_UIPanelDef.KIND_DEBUG:   return debug_layer
		_: return screen_layer


# ============================================================
# 场景加载
# ============================================================

func load_world(p_scene_path: String, p_data: Dictionary = {}) -> GF_OperationResult:
	_clear_children(world_mount)
	return _load_into(world_mount, p_scene_path, p_data)


func load_ui_panel(p_kind: StringName, p_scene_path: String, p_data: Dictionary = {}) -> GF_OperationResult:
	return _load_into(get_ui_layer(p_kind), p_scene_path, p_data)


func unload_world() -> void:
	for child in world_mount.get_children():
		if child.has_method("_on_world_exit"):
			child._on_world_exit()
	_clear_children(world_mount)
	_log.info("GF_SceneHost", "世界已卸载")


func replace_world(p_scene_path: String, p_data: Dictionary = {}) -> GF_OperationResult:
	var node_result := _scene_factory.create(p_scene_path, p_data)
	if node_result.is_fail():
		return node_result

	var new_node: Node = node_result.data
	var old_root: Node = world_mount.get_child(0) if world_mount.get_child_count() > 0 else null

	if new_node is GF_WorldRoot and _world_context != null:
		var wr := new_node as GF_WorldRoot
		wr._bootstrap = _world_context
		wr._on_world_setup()

	if _world_context != null:
		var save_svc = _bootstrap.service(GF_SaveService) if _bootstrap != null else null
		if save_svc != null and save_svc.has_method("on_world_switch"):
			save_svc.on_world_switch(old_root, new_node)

	unload_world()
	world_mount.add_child(new_node)
	_log.info("GF_SceneHost", "世界已切换: %s" % p_scene_path)
	return GF_OperationResult.ok(new_node)


func clear_world() -> void:
	_clear_children(world_mount)


func clear_layer(p_kind: StringName) -> void:
	_clear_children(get_ui_layer(p_kind))


func _load_into(p_target: Node, p_scene_path: String, p_data: Dictionary) -> GF_OperationResult:
	var result := _scene_factory.create(p_scene_path, p_data)
	if result.is_fail():
		if _log != null:
			_log.error("GF_SceneHost", "加载场景失败: %s — %s" % [p_scene_path, result.error.message])
		return result

	var node: Node = result.data
	p_target.add_child(node)
	if _log != null:
		_log.info("GF_SceneHost", "已加载: %s" % p_scene_path)
	return GF_OperationResult.ok(node)


func _clear_children(p_parent: Node) -> void:
	for child in p_parent.get_children():
		child.queue_free()
