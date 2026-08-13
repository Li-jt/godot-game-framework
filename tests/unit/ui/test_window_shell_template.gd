# tests/unit/ui/test_window_shell_template.gd
## window_shell.tscn 模板结构校验。
## 模板脚本引用使用 addons 安装视角路径（与 default_main.tscn 一致），
## 在本框架仓库内悬空、无法用 load() 解析，故用纯文本断言校验结构。
extends GutTest

const TEMPLATE_PATH := "res://scenes/ui/window_shell.tscn"


func _load_text() -> String:
	var text := FileAccess.get_file_as_string(TEMPLATE_PATH)
	assert_false(text.is_empty(), "模板文件应存在且可读")
	return text


func test_template_references_window_scripts() -> void:
	var text := _load_text()
	assert_true(text.contains("ui_window.gd"), "模板应引用 GF_UIWindow 脚本")
	assert_true(text.contains("ui_resize_handle.gd"), "模板应引用 GF_ResizeHandle 脚本")


func test_template_has_eight_resize_handles() -> void:
	var text := _load_text()
	assert_eq(text.count("script = ExtResource(\"2_handle\")"), 8, "应有 8 个缩放手柄")


func test_template_has_all_eight_edges() -> void:
	var text := _load_text()
	var edges: Array[int] = [1, 2, 4, 8, 5, 6, 9, 10]
	for edge_value in edges:
		assert_true(text.contains("edge = %d" % edge_value), "应包含 edge = %d 的手柄" % edge_value)


func test_template_wires_drag_area() -> void:
	var text := _load_text()
	assert_true(text.contains("drag_area = NodePath(\"TitleBar\")"), "根节点应把 TitleBar 拖入 drag_area")


func test_template_has_title_bar_and_content() -> void:
	var text := _load_text()
	assert_true(text.contains("TitleBar"), "应有标题栏")
	assert_true(text.contains("ContentBox"), "应有内容容器")
