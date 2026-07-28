## UIDragGhost
## 拖拽视觉控件。游戏层通过 event.show_ghost_xxx() 一键创建，
## 无需手写 TextureRect 管理代码。
##
## 支持三种模式：
## 1. 纯图标：show_with_texture(tex, offset)
## 2. 图标 + 数量：show_with_item(tex, count, offset)
## 3. 纯文本：show_with_text("+100 金币")
##
## 自动挂载到 SYSTEM 层（最顶层），确保不被任何面板遮挡。
## mouse_filter = IGNORE，不拦截鼠标事件。
class_name UIDragGhost
extends Control

var _offset: Vector2 = Vector2.ZERO

var _icon: TextureRect = null
var _count_label: Label = null
var _text_label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_children()


func _create_children() -> void:
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.hide()
	add_child(_icon)

	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.hide()
	add_child(_count_label)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.hide()
	add_child(_text_label)


## 显示纯图标。p_offset 为图标相对于鼠标的偏移，默认 (-24, -24) 即居中。
func show_with_texture(p_texture: Texture2D, p_offset: Vector2 = Vector2(-24, -24)) -> void:
	_offset = p_offset
	_icon.texture = p_texture
	_icon.size = p_texture.get_size()
	_icon.show()
	_count_label.hide()
	_text_label.hide()
	size = p_texture.get_size()
	pivot_offset = -p_offset
	show()
	global_position = get_global_mouse_position() + _offset


## 显示图标 + 数量。数量 > 1 时显示 "× N" 标签。
func show_with_item(p_texture: Texture2D, p_count: int, p_offset: Vector2 = Vector2(-24, -24)) -> void:
	_offset = p_offset
	_icon.texture = p_texture
	_icon.size = p_texture.get_size()
	_icon.show()

	if p_count > 1:
		_count_label.text = "×%d" % p_count
		_count_label.position = Vector2(p_texture.get_size().x, p_texture.get_size().y - 16)
		_count_label.show()
	else:
		_count_label.hide()

	_text_label.hide()
	size = p_texture.get_size()
	pivot_offset = -p_offset
	show()
	global_position = get_global_mouse_position() + _offset


## 显示纯文本。用于非图标类的拖拽信息展示。
func show_with_text(p_text: String) -> void:
	_offset = Vector2.ZERO
	_icon.hide()
	_count_label.hide()
	_text_label.text = p_text
	_text_label.show()
	size = Vector2.ZERO
	show()
	global_position = get_global_mouse_position() + _offset


## 每帧由 UIDragManager._input 调用，跟随鼠标
func _follow(p_screen_pos: Vector2) -> void:
	global_position = p_screen_pos + _offset


## 由 UIDragManager._clear 在拖拽结束时调用
func dismiss() -> void:
	hide()
	queue_free()
