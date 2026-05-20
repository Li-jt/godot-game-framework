## SceneHost
## 场景宿主。管理持久挂载点、相机和 UI 层级，协调场景切换。
##
## 节点结构定义在 scene_host.tscn 中，编辑器可直接查看和调整。
##
## 场景树：
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

var world_root: Node2D
var game_camera: Camera2D
var ui_canvas: CanvasLayer
var ui_root: Control

var hud_layer: Control
var screen_layer: Control
var popup_layer: Control
var tooltip_layer: Control
var system_layer: Control
var debug_layer: Control

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
	world_root = $WorldMount as Node2D
	game_camera = $GameCamera as Camera2D
	game_camera.enabled = true
	game_camera.make_current()

	ui_canvas = $UiCanvas as CanvasLayer
	ui_root = $UiCanvas/UIRoot as Control

	hud_layer = $UiCanvas/UIRoot/HudLayer as Control
	screen_layer = $UiCanvas/UIRoot/ScreenLayer as Control
	popup_layer = $UiCanvas/UIRoot/PopupLayer as Control
	tooltip_layer = $UiCanvas/UIRoot/TooltipLayer as Control
	system_layer = $UiCanvas/UIRoot/SystemLayer as Control
	debug_layer = $UiCanvas/UIRoot/DebugLayer as Control


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
