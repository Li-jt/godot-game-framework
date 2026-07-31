## GF_EditorPlugin — 框架编辑器工具入口。
## 注册框架文件模板右键菜单等编辑器增强功能。
## 用户需将此 addon 安装到 addons/gf_editor_tools/ 并在项目设置中启用。
@tool
class_name GF_EditorPlugin
extends EditorPlugin


var _new_file_menu: GF_NewFileContextMenu = null


func _enter_tree() -> void:
	# 注册文件模板右键菜单到文件系统的"新建"子菜单
	_new_file_menu = GF_NewFileContextMenu.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE, _new_file_menu)
	print("[GF EditorTools] 编辑器工具已加载（8 种文件模板）")


func _exit_tree() -> void:
	if is_instance_valid(_new_file_menu):
		remove_context_menu_plugin(_new_file_menu)
		_new_file_menu = null
	print("[GF EditorTools] 编辑器工具已卸载")
