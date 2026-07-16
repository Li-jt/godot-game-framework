## DefJsonLoader — 通用的 JSON 定义文件加载工具。
## 支持多个文件合并加载，后加载的覆盖同名字段。
## 供 UI/Audio/Input 等模块从 JSON 加载定义数据。
class_name DefJsonLoader
extends RefCounted


## 加载一个 JSON 定义文件。返回 Dictionary，加载失败返回空字典。
static func load_file(p_fs: FileSystemService, p_path: String) -> Dictionary:
	if not p_fs.file_exists(p_path):
		push_warning("[DefJsonLoader] 文件不存在: %s" % p_path)
		return {}
	var text := p_fs.read_text(p_path)
	if text.is_empty():
		return {}
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[DefJsonLoader] 解析 %s 失败: %s" % [p_path, json.get_error_message()])
		return {}
	return json.data


## 加载多个 JSON 文件并深度合并。p_paths 中靠后的覆盖靠前的。
static func load_and_merge(p_fs: FileSystemService, p_paths: Array[String]) -> Dictionary:
	var result := {}
	for path in p_paths:
		var data := load_file(p_fs, path)
		_deep_merge(result, data)
	return result


## 深度合并两个字典。src 中的值覆盖 dst 中的同级值。
static func _deep_merge(p_dst: Dictionary, p_src: Dictionary) -> void:
	for key in p_src:
		if p_dst.has(key) and p_dst[key] is Dictionary and p_src[key] is Dictionary:
			_deep_merge(p_dst[key], p_src[key])
		else:
			p_dst[key] = p_src[key]
