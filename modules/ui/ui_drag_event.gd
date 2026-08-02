## GF_UIDragEvent
## 拖拽事件数据。框架在 begin_drag 时创建，贯穿整个拖拽周期。
## 游戏层在 on_begin_drag 回调中填写 drag_data。
class_name GF_UIDragEvent
extends RefCounted

## 当前屏幕坐标（框架每帧更新）
var position: Vector2 = Vector2.ZERO

## 位移增量 — 本帧移动量（框架每帧更新）
var delta: Vector2 = Vector2.ZERO

## 哪个鼠标按键触发的拖拽
var button: int = MOUSE_BUTTON_LEFT

## 拖拽源面板（框架自动填充）
var drag_source: GF_UIPanel = null

## 拖拽携带的数据（游戏层在 on_begin_drag 中填写）
## 例：{ "item_id": "iron_sword", "count": 5, "from_slot": 3 }
var drag_data: Dictionary = {}

## 松手时指针下方的接收者（框架在 on_drop 路由时暂存）
## null 表示没有接收者接受此次拖拽
var drop_receiver: Variant = null

## 内部回调：由 GF_UIDragManager 在创建 event 时设置。用于将 ghost 附着到场景树。
var _attach_ghost_cb: Callable


## [L2] 显示图标跟随鼠标。游戏层在 on_begin_drag 中调用。
## 返回 GF_UIDragGhost 供游戏层进一步定制（如设置数量文本）。
func show_ghost_texture(p_texture: Texture2D, p_offset: Vector2 = Vector2(-24, -24)) -> GF_UIDragGhost:
	var ghost := GF_UIDragGhost.new()
	ghost.show_with_texture(p_texture, p_offset)
	_attach(ghost)
	return ghost


## [L2] 显示图标 + 数量。例：铁矿石图标下显示 "× 5"。
func show_ghost_item(p_texture: Texture2D, p_count: int, p_offset: Vector2 = Vector2(-24, -24)) -> GF_UIDragGhost:
	var ghost := GF_UIDragGhost.new()
	ghost.show_with_item(p_texture, p_count, p_offset)
	_attach(ghost)
	return ghost


## [L2] 显示纯文本拖拽。例：拖拽 "+100 金币"。
func show_ghost_text(p_text: String) -> GF_UIDragGhost:
	var ghost := GF_UIDragGhost.new()
	ghost.show_with_text(p_text)
	_attach(ghost)
	return ghost


func _attach(p_ghost: GF_UIDragGhost) -> void:
	if _attach_ghost_cb.is_valid():
		_attach_ghost_cb.call(p_ghost)
