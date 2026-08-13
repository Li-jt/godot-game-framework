## GF_NewFileContextMenu — 框架文件模板右键菜单。
## 挂载到 FileSystem 的"新建"子菜单，按分组提供 8 种文件模板快速创建入口。
@tool
class_name GF_NewFileContextMenu
extends EditorContextMenuPlugin


# ============================================================
# 模板定义：label, base_class, suffix, help_name, 模板构建方法
# ============================================================

const GROUP_ECS := "ECS"
const GROUP_GAME := "Game"

const _TEMPLATES: Array[Dictionary] = [
	# -- ECS 组 --
	{
		label = "Component",
		base_class = "GF_EcsComponentBase",
		class_suffix = "Component",
		file_suffix = "_component.gd",
		dialog_title = "新建 ECS Component",
		build = "_build_component_template",
		help_name = "health",
		group = GROUP_ECS,
	},
	{
		label = "System",
		base_class = "GF_EcsSystem",
		class_suffix = "System",
		file_suffix = "_system.gd",
		dialog_title = "新建 ECS System",
		build = "_build_system_template",
		help_name = "movement",
		group = GROUP_ECS,
	},
	{
		label = "Command",
		base_class = "GF_ICommand",
		class_suffix = "Command",
		file_suffix = "_command.gd",
		dialog_title = "新建 ECS Command",
		build = "_build_command_template",
		help_name = "place_building",
		group = GROUP_ECS,
	},
	# -- Game 组 --
	{
		label = "UI Panel",
		base_class = "GF_UIPanel",
		class_suffix = "Panel",
		file_suffix = "_panel.gd",
		dialog_title = "新建 UI Panel",
		build = "_build_ui_panel_template",
		help_name = "inventory",
		group = GROUP_GAME,
	},
	{
		label = "Module Service",
		base_class = "GF_ModuleLifecycle",
		class_suffix = "Service",
		file_suffix = "_service.gd",
		dialog_title = "新建 Module Service",
		build = "_build_module_service_template",
		help_name = "trade",
		group = GROUP_GAME,
	},
	{
		label = "Saveable Module",
		base_class = "GF_ISaveable",
		class_suffix = "Saveable",
		file_suffix = "_saveable.gd",
		dialog_title = "新建 Saveable Module",
		build = "_build_saveable_template",
		help_name = "inventory",
		group = GROUP_GAME,
	},
	{
		label = "World Root",
		base_class = "GF_WorldRoot",
		class_suffix = "World",
		file_suffix = "_world.gd",
		dialog_title = "新建 World Root",
		build = "_build_world_root_template",
		help_name = "dungeon",
		group = GROUP_GAME,
	},
	{
		label = "App Bootstrap",
		base_class = "GF_AppBootstrap",
		class_suffix = "Bootstrap",
		file_suffix = "_bootstrap.gd",
		dialog_title = "新建 App Bootstrap",
		build = "_build_app_bootstrap_template",
		help_name = "my_game",
		group = GROUP_GAME,
	},
]


var _pending_paths: PackedStringArray = []
var _menu_id_to_template: Dictionary = {}  # {PopupMenu: {int_id: template_dict}}


# ============================================================
# EditorContextMenuPlugin 入口
# ============================================================

func _popup_menu(paths: PackedStringArray) -> void:
	_pending_paths = paths
	_menu_id_to_template.clear()

	# 按分组聚合模板
	var groups: Dictionary = {}
	for tmpl in _TEMPLATES:
		var g: String = tmpl.group
		if not groups.has(g):
			groups[g] = []
		groups[g].append(tmpl)

	# 为每个分组创建子菜单
	for group_name in groups:
		var submenu := PopupMenu.new()
		var group_templates: Array = groups[group_name]
		for i in group_templates.size():
			var tmpl: Dictionary = group_templates[i]
			submenu.add_item(tmpl.label, i)
		submenu.id_pressed.connect(_on_submenu_clicked.bind(submenu))
		_menu_id_to_template[submenu] = group_templates

		add_context_submenu_item(group_name, submenu)


func _on_submenu_clicked(p_id: int, p_menu: PopupMenu) -> void:
	var group_templates: Array = _menu_id_to_template.get(p_menu, [])
	if p_id < 0 or p_id >= group_templates.size():
		return
	var tmpl: Dictionary = group_templates[p_id]
	_show_create_dialog(_pending_paths, tmpl)


# ============================================================
# 创建对话框
# ============================================================

func _show_create_dialog(p_paths: PackedStringArray, p_tmpl: Dictionary) -> void:
	var base_control := EditorInterface.get_base_control()

	var dialog := AcceptDialog.new()
	dialog.title = p_tmpl.dialog_title
	dialog.ok_button_text = "创建"
	dialog.exclusive = true

	var target_dir := _resolve_target_dir(p_paths)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var dir_label := Label.new()
	dir_label.text = "目标目录: %s" % target_dir
	vbox.add_child(dir_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var name_label := Label.new()
	name_label.text = "名称（如 %s）:" % p_tmpl.help_name
	vbox.add_child(name_label)

	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.placeholder_text = "输入名称"
	name_edit.select_all_on_focus = true
	name_edit.custom_minimum_size = Vector2(320, 0)
	vbox.add_child(name_edit)

	base_control.add_child(dialog)

	dialog.confirmed.connect(func():
		var raw_name: String = name_edit.text.strip_edges()
		if raw_name.is_empty():
			_show_error("请输入名称")
			return
		var class_name_str := _derive_class_name(raw_name, p_tmpl.class_suffix)
		var file_name := _derive_file_name(raw_name, p_tmpl.file_suffix)
		var file_path := target_dir.path_join(file_name)
		if FileAccess.file_exists(file_path):
			_show_error("文件已存在:\n%s" % file_name)
			return
		var build_method: String = p_tmpl.build
		var content: String = call(build_method, class_name_str, raw_name)
		_write_file(file_path, content)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	dialog.popup_centered(Vector2i(450, 170))
	name_edit.grab_focus()


# ============================================================
# 路径与文件工具
# ============================================================

func _resolve_target_dir(p_paths: PackedStringArray) -> String:
	if p_paths.is_empty():
		return "res://"
	var path: String = p_paths[0]
	if DirAccess.dir_exists_absolute(path):
		return path
	return path.get_base_dir()


func _write_file(p_path: String, p_content: String) -> void:
	var dir := p_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var file := FileAccess.open(p_path, FileAccess.WRITE)
	if file == null:
		push_error("[GF EditorTools] 无法创建文件: %s" % p_path)
		_show_error("无法创建文件:\n%s" % p_path)
		return
	file.store_string(p_content)

	EditorInterface.get_resource_filesystem().scan()
	print("[GF EditorTools] 已创建: %s" % p_path)


# ============================================================
# 名称推导
# ============================================================

func _derive_class_name(p_raw: String, p_suffix: String) -> String:
	var name := p_raw
	var suffix_snake := _pascal_to_snake(p_suffix)
	if name.ends_with("_" + suffix_snake):
		name = name.substr(0, name.length() - suffix_snake.length() - 1)
	elif name.ends_with(suffix_snake):
		name = name.substr(0, name.length() - suffix_snake.length())
	elif name.ends_with(p_suffix):
		name = name.substr(0, name.length() - p_suffix.length())

	var result := ""
	for i in name.length():
		var ch := name[i]
		if ch == "_":
			continue
		if i == 0 or name[i - 1] == "_":
			result += ch.to_upper()
		else:
			result += ch

	if not result.ends_with(p_suffix):
		result += p_suffix
	return result


func _derive_file_name(p_raw: String, p_file_suffix: String) -> String:
	var name := p_raw
	var base_name := _pascal_to_snake(p_file_suffix.trim_suffix(".gd"))
	if name.ends_with("_" + base_name):
		name = name.substr(0, name.length() - base_name.length() - 1)
	elif name.ends_with(base_name):
		name = name.substr(0, name.length() - base_name.length())
	elif name.ends_with(_snake_to_pascal(base_name)):
		name = name.substr(0, name.length() - _snake_to_pascal(base_name).length())

	return _pascal_to_snake(name) + p_file_suffix


func _pascal_to_snake(p_name: String) -> String:
	var result := ""
	for i in p_name.length():
		var ch := p_name[i]
		if ch == "_":
			result += "_"
		elif i > 0 and ch >= "A" and ch <= "Z" and p_name[i - 1] != "_" and result.length() > 0:
			result += "_" + ch.to_lower()
		else:
			result += ch.to_lower()
	return result


func _snake_to_pascal(p_name: String) -> String:
	var result := ""
	for i in p_name.length():
		var ch := p_name[i]
		if ch == "_":
			continue
		if i == 0 or p_name[i - 1] == "_":
			result += ch.to_upper()
		else:
			result += ch
	return result


# ============================================================
# ECS 组模板
# ============================================================

func _build_component_template(p_class: String, _p_raw: String) -> String:
	return _join([
		"## %s 组件数据。class_name 即为类型标识，无需额外注册。" % p_class,
		"class_name %s" % p_class,
		"extends GF_EcsComponentBase",
		"",
		"",
		"func serialize() -> Dictionary:",
		"\treturn {}",
		"",
		"",
		"func deserialize(p_data: Dictionary) -> void:",
		"\tpass",
		"",
	])


func _build_system_template(p_class: String, _p_raw: String) -> String:
	return _join([
		"## %s 系统逻辑。" % p_class,
		"class_name %s" % p_class,
		"extends GF_EcsSystem",
		"",
		"",
		"func on_init(p_world: GF_EcsWorld) -> void:",
		"\tpass",
		"",
		"",
		"func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:",
		"\tpass",
		"",
		"",
		"func on_shutdown() -> void:",
		"\tpass",
		"",
	])


func _build_command_template(p_class: String, p_raw: String) -> String:
	var key := ""
	if "_" in p_raw and not p_raw.begins_with("_"):
		key = p_raw.to_lower()
	else:
		key = _pascal_to_snake(p_class.trim_suffix("Command"))
	return _join([
		"## %s 命令。" % p_class,
		"class_name %s" % p_class,
		"extends GF_ICommand",
		"",
		"",
		"func command_key() -> String:",
		"\treturn \"%s\"" % key,
		"",
		"",
		"func execute(_p_context: Dictionary) -> GF_OperationResult:",
		"\treturn GF_OperationResult.ok()",
		"",
		"",
		"func validate(_p_context: Dictionary) -> GF_OperationResult:",
		"\treturn GF_OperationResult.ok()",
		"",
	])


# ============================================================
# Game 组模板
# ============================================================

func _build_ui_panel_template(p_class: String, _p_raw: String) -> String:
	return _join([
		"## %s UI 面板。通过 _bootstrap.service(GF_XxxService) 获取所需服务。" % p_class,
		"class_name %s" % p_class,
		"extends GF_UIPanel",
		"",
		"",
		"func _on_open(_p_data: Dictionary) -> void:",
		"\t# var log := _bootstrap.service(GF_LogService) as GF_LogService",
		"\tpass",
		"",
		"",
		"func _on_close() -> void:",
		"\tpass",
		"",
		"",
		"func _on_hide() -> void:",
		"\tpass",
		"",
		"",
		"func _on_reopen(_p_data: Dictionary) -> void:",
		"\tpass",
		"",
	])


func _build_module_service_template(p_class: String, _p_raw: String) -> String:
	return _join([
		"## %s 模块服务。" % p_class,
		"class_name %s" % p_class,
		"extends GF_ModuleLifecycle",
		"",
		"",
		"func _on_init() -> GF_OperationResult:",
		"\treturn GF_OperationResult.ok()",
		"",
		"",
		"func dependencies() -> Array:",
		"\treturn [GF_LogService]",
		"",
		"",
		"func configure() -> GF_OperationResult:",
		"\tvar log: GF_LogService = _bootstrap.service(GF_LogService) as GF_LogService",
		"\treturn GF_OperationResult.ok()",
		"",
		"",
		"func _on_dispose() -> GF_OperationResult:",
		"\treturn GF_OperationResult.ok()",
		"",
	])


func _build_saveable_template(p_class: String, p_raw: String) -> String:
	var key := ""
	if "_" in p_raw and not p_raw.begins_with("_"):
		key = p_raw.to_lower()
	else:
		key = _pascal_to_snake(p_class.trim_suffix("Saveable"))
	return _join([
		"## %s 存档模块。" % p_class,
		"class_name %s" % p_class,
		"extends GF_ISaveable",
		"",
		"",
		"func save_key() -> String:",
		"\treturn \"%s\"" % key,
		"",
		"",
		"func on_save() -> Dictionary:",
		"\treturn {}",
		"",
		"",
		"func on_load(p_data: Dictionary) -> void:",
		"\tpass",
		"",
	])


func _build_world_root_template(p_class: String, _p_raw: String) -> String:
	return _join([
		"## %s 世界根节点。" % p_class,
		"class_name %s" % p_class,
		"extends GF_WorldRoot",
		"",
		"",
		"func _on_world_setup() -> void:",
		"\tpass",
		"",
		"",
		"func _on_world_exit() -> void:",
		"\tpass",
		"",
	])


func _build_app_bootstrap_template(p_class: String, _p_raw: String) -> String:
	return _join([
		"## %s 应用启动引导。" % p_class,
		"class_name %s" % p_class,
		"extends GF_AppBootstrap",
		"",
		"",
		"func _assemble() -> void:",
		"\t# 框架内置了 6 个基础服务，按需注册可选模块",
		"\tregister(GF_EcsWorld.new())",
		"\tregister(GF_EcsScheduler.new())",
		"\t# register(GF_SaveService.new())   # 不注册就不存在",
		"\t# register(GF_InputService.new())  # 不注册就不存在",
		"",
		"",
		"func _on_ready() -> void:",
		"\tvar log := service(GF_LogService) as GF_LogService",
		"\tlog.info(\"%s\", \"启动完成\")" % p_class,
		"",
	])


# ============================================================
# 工具
# ============================================================

func _join(p_lines: PackedStringArray) -> String:
	return "\n".join(p_lines)


func _show_error(p_message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "错误"
	dialog.dialog_text = p_message
	dialog.ok_button_text = "确定"
	var base_control := EditorInterface.get_base_control()
	base_control.add_child(dialog)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.popup_centered()
