## SceneHost
## 场景宿主。管理持久挂载点、相机和 UI 层级，协调场景切换。
##
## 场景树结构：
##   Main (GameBootstrap)
##   └── SceneHost
##       ├── WorldRoot   (Node2D)     — 游戏世界挂载点，受 GameCamera 影响
##       ├── GameCamera  (Camera2D)   — 游戏世界相机（用户可拖动/缩放）
##       └── UiCanvas    (CanvasLayer) — UI 层（独立于游戏相机，固定屏幕渲染）
##           └── UIRoot  (Control)
##               ├── HudLayer
##               ├── ScreenLayer
##               ├── PopupLayer
##               ├── TooltipLayer
##               ├── SystemLayer
##               └── DebugLayer
class_name SceneHost
extends Node

var world_root: Node2D = null
var game_camera: Camera2D = null
var ui_canvas: CanvasLayer = null
var ui_root: Control = null

var hud_layer: Control = null
var screen_layer: Control = null
var popup_layer: Control = null
var tooltip_layer: Control = null
var system_layer: Control = null
var debug_layer: Control = null

var _scene_factory: SceneFactory = null
var _log: LogService = null

## 世界上下文。Game 层通过 set_world_context() 注入，后续所有世界加载自动传入。
var _world_context: GameServices = null


func configure(p_scene_factory: SceneFactory, p_log: LogService) -> OperationResult:
	if p_scene_factory == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: scene_factory 不能为 null", name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", name)
	_scene_factory = p_scene_factory
	_log = p_log
	return OperationResult.ok()


func _ready() -> void:
	_create_mount_points()


func is_runtime_ready() -> bool:
	return world_root != null and ui_root != null and hud_layer != null


# ============================================================
# 世界上下文
# ============================================================

func set_world_context(p_ctx: GameServices) -> void:
	_world_context = p_ctx


# ============================================================
# 挂载点
# ============================================================

func get_world_root() -> Node2D:
	return world_root


func get_camera() -> Camera2D:
	return game_camera


func get_ui_root() -> Control:
	return ui_root


func get_ui_canvas() -> CanvasLayer:
	return ui_canvas


## 根据 PanelKind 返回对应 UI 层
func get_ui_layer(p_kind: UIPanelDef.PanelKind) -> Control:
	match p_kind:
		UIPanelDef.PanelKind.HUD:     return hud_layer
		UIPanelDef.PanelKind.SCREEN:  return screen_layer
		UIPanelDef.PanelKind.POPUP:   return popup_layer
		UIPanelDef.PanelKind.TOOLTIP: return tooltip_layer
		UIPanelDef.PanelKind.SYSTEM:  return system_layer
		UIPanelDef.PanelKind.DEBUG:   return debug_layer
		_: return screen_layer


# ============================================================
# 场景加载
# ============================================================

func load_world(p_scene_path: String, p_data: Dictionary = {}) -> OperationResult:
	_clear_children(world_root)
	return _load_into(world_root, p_scene_path, p_data)


func load_ui_panel(p_kind: UIPanelDef.PanelKind, p_scene_path: String, p_data: Dictionary = {}) -> OperationResult:
	return _load_into(get_ui_layer(p_kind), p_scene_path, p_data)


func unload_world() -> void:
	for child in world_root.get_children():
		if child.has_method("_on_world_exit"):
			child._on_world_exit()
	_clear_children(world_root)
	_log.info("SceneHost", "世界已卸载")


func replace_world(p_scene_path: String, p_data: Dictionary = {}) -> OperationResult:
	var node_result := _scene_factory.create(p_scene_path, p_data)
	if node_result.is_fail():
		return node_result

	var new_node: Node = node_result.data

	if new_node is WorldRoot and _world_context != null:
		var wr := new_node as WorldRoot
		wr.ctx = _world_context
		wr._on_world_setup()

	unload_world()
	world_root.add_child(new_node)
	_log.info("SceneHost", "世界已切换: %s" % p_scene_path)
	return OperationResult.ok(new_node)


func clear_world() -> void:
	_clear_children(world_root)


func clear_layer(p_kind: UIPanelDef.PanelKind) -> void:
	_clear_children(get_ui_layer(p_kind))


# ============================================================
# 内部
# ============================================================

func _create_mount_points() -> void:
	# 世界挂载点
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	# 游戏相机（渲染世界，用户可拖动/缩放）
	game_camera = Camera2D.new()
	game_camera.name = "GameCamera"
	game_camera.position = Vector2(640, 360)
	game_camera.zoom = Vector2(1.5, 1.5)
	add_child(game_camera)
	game_camera.enabled = true
	game_camera.make_current()

	# UI CanvasLayer（独立于游戏相机的固定屏幕渲染层）
	ui_canvas = CanvasLayer.new()
	ui_canvas.name = "UiCanvas"
	ui_canvas.layer = 100
	ui_canvas.follow_viewport_enabled = false
	add_child(ui_canvas)

	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_canvas.add_child(ui_root)

	hud_layer = _create_ui_layer("HudLayer")
	screen_layer = _create_ui_layer("ScreenLayer")
	popup_layer = _create_ui_layer("PopupLayer")
	tooltip_layer = _create_ui_layer("TooltipLayer")
	system_layer = _create_ui_layer("SystemLayer")
	debug_layer = _create_ui_layer("DebugLayer")


func _create_ui_layer(p_name: String) -> Control:
	var layer := Control.new()
	layer.name = p_name
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(layer)
	return layer


func _load_into(p_target: Node, p_scene_path: String, p_data: Dictionary) -> OperationResult:
	var result := _scene_factory.create(p_scene_path, p_data)
	if result.is_fail():
		_log.error("SceneHost", "加载场景失败: %s — %s" % [p_scene_path, result.error.message])
		return result

	var node: Node = result.data
	p_target.add_child(node)
	_log.info("SceneHost", "已加载: %s" % p_scene_path)
	return OperationResult.ok(node)


func _clear_children(p_parent: Node) -> void:
	for child in p_parent.get_children():
		child.queue_free()
