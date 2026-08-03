## GF_FileSystemService
## 统一文件系统服务，封装 Godot FileAccess / DirAccess。
## 所有模块的文件读写、目录操作必须通过此服务，禁止直接使用 FileAccess。
##
## 所有方法返回 GF_OperationResult：
##   - 成功时 data 为读取内容（String 或 Dictionary）
##   - 失败时 error 包含错误码和描述
class_name GF_FileSystemService
extends GF_ModuleLifecycle


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


# ============================================================
# 存在性检查
# ============================================================

## 文件是否存在
func file_exists(p_path: String) -> bool:
	return FileAccess.file_exists(p_path)


## 获取文件最后修改时间（Unix 时间戳）。文件不存在返回 0。
func get_modified_time(p_path: String) -> int:
	if not FileAccess.file_exists(p_path):
		return 0
	return FileAccess.get_modified_time(p_path)


## 目录是否存在
func dir_exists(p_path: String) -> bool:
	return DirAccess.dir_exists_absolute(p_path)


# ============================================================
# 目录操作
# ============================================================

## 确保目录存在（递归创建），返回 GF_OperationResult
func ensure_dir(p_path: String) -> GF_OperationResult:
	if dir_exists(p_path):
		return GF_OperationResult.ok()

	var err := DirAccess.make_dir_recursive_absolute(p_path)
	if err != OK:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"无法创建目录: %s (error %d)" % [p_path, err],
			module_name
		)
	return GF_OperationResult.ok()


## 列出目录下的文件（仅文件名，不含子目录）。失败返回 fail
func list_files(p_dir: String) -> GF_OperationResult:
	if not dir_exists(p_dir):
		return GF_OperationResult.ok([])

	var files: Array = []
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "无法打开目录: %s" % p_dir, module_name)

	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			files.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return GF_OperationResult.ok(files)


## 列出目录下的文件（返回完整路径，不含子目录）。
func list_files_full(p_dir: String) -> GF_OperationResult:
	var result := list_files(p_dir)
	if result.is_fail():
		return result
	var names: Array = result.data
	var full_paths: Array[String] = []
	for name in names:
		full_paths.append(p_dir.path_join(name))
	return GF_OperationResult.ok(full_paths)


## 列出目录下的文件（递归，包含所有子目录）。
## [param p_extensions] 可选，指定后缀过滤（如 ["gd", "tscn"]），为空则返回所有文件。
func list_files_recursive(p_dir: String, p_extensions: Array[String] = []) -> GF_OperationResult:
	if not dir_exists(p_dir):
		return GF_OperationResult.ok([])

	var files: Array[String] = []
	_list_recursive(p_dir, files, p_extensions)
	return GF_OperationResult.ok(files)


func _list_recursive(p_dir: String, p_out_files: Array[String], p_extensions: Array[String]) -> void:
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue

		var full_path := p_dir.path_join(name)
		if dir.current_is_dir():
			_list_recursive(full_path, p_out_files, p_extensions)
		else:
			if _match_extensions(name, p_extensions):
				p_out_files.append(full_path)
		name = dir.get_next()
	dir.list_dir_end()


## 列出目录下的子目录（仅目录名，不含文件，非递归）。
func list_directories(p_dir: String) -> GF_OperationResult:
	if not dir_exists(p_dir):
		return GF_OperationResult.ok([])

	var dirs: Array[String] = []
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "无法打开目录: %s" % p_dir, module_name)

	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name != "." and name != ".." and dir.current_is_dir():
			dirs.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return GF_OperationResult.ok(dirs)


## 递归列出目录下的所有子目录。
func list_directories_recursive(p_dir: String) -> GF_OperationResult:
	if not dir_exists(p_dir):
		return GF_OperationResult.ok([])

	var dirs: Array[String] = []
	_list_dirs_recursive(p_dir, dirs)
	return GF_OperationResult.ok(dirs)


func _list_dirs_recursive(p_dir: String, p_out_dirs: Array[String]) -> void:
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue

		var full_path := p_dir.path_join(name)
		if dir.current_is_dir():
			p_out_dirs.append(full_path)
			_list_dirs_recursive(full_path, p_out_dirs)
		name = dir.get_next()
	dir.list_dir_end()


# ============================================================
# 文件信息
# ============================================================

## 获取文件大小（字节）。文件不存在返回 -1。
func get_file_size(p_path: String) -> int:
	if not file_exists(p_path):
		return -1
	var fa := FileAccess.open(p_path, FileAccess.READ)
	if fa == null:
		return -1
	var size := fa.get_length()
	fa.close()
	return size


## 获取文件名（不含路径）。
func get_file_name(p_path: String) -> String:
	return p_path.get_file()


## 获取文件扩展名（不含点，如 "gd"）。
func get_extension(p_path: String) -> String:
	return p_path.get_extension()


## 获取不含扩展名的文件名。
func get_base_name(p_path: String) -> String:
	return p_path.get_file().trim_suffix("." + p_path.get_extension())


# ============================================================
# 内部
# ============================================================

## 检查文件名是否匹配扩展名列表。p_extensions 为空则全部通过。
func _match_extensions(p_name: String, p_extensions: Array[String]) -> bool:
	if p_extensions.is_empty():
		return true
	var ext := p_name.get_extension().to_lower()
	for e in p_extensions:
		if ext == e.to_lower():
			return true
	return false


## 原子写入：先写临时文件 .tmp → rename 替换目标。写入过程中崩溃不会损坏原文件。
func write_text_atomic(p_path: String, p_content: String) -> GF_OperationResult:
	var dir := p_path.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result

	var tmp_path := p_path + ".tmp"
	var fa := FileAccess.open(tmp_path, FileAccess.WRITE)
	if fa == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "无法写入临时文件: %s" % tmp_path, module_name)

	fa.store_string(p_content)
	fa.close()

	var err := DirAccess.rename_absolute(tmp_path, p_path)
	if err != OK:
		DirAccess.remove_absolute(tmp_path)
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "原子写入 rename 失败: %s → %s" % [tmp_path, p_path], module_name)

	return GF_OperationResult.ok()


## 备份文件：复制为 .bak。原文件不存在则跳过。
func backup_file(p_path: String) -> GF_OperationResult:
	if not file_exists(p_path):
		return GF_OperationResult.ok()
	return copy_file(p_path, p_path + ".bak")


## 复制文件。
func copy_file(p_from: String, p_to: String) -> GF_OperationResult:
	if not file_exists(p_from):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "源文件不存在: %s" % p_from, module_name)
	var read_result := read_text(p_from)
	if read_result.is_fail():
		return read_result
	return write_text(p_to, read_result.data as String)


## 移动/重命名文件。
func move_file(p_from: String, p_to: String) -> GF_OperationResult:
	if not file_exists(p_from):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "源文件不存在: %s" % p_from, module_name)
	var dir := p_to.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result
	var err := DirAccess.rename_absolute(p_from, p_to)
	if err != OK:
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "移动文件失败: %s → %s" % [p_from, p_to], module_name)
	return GF_OperationResult.ok()


## 删除文件
func delete_file(p_path: String) -> GF_OperationResult:
	if not file_exists(p_path):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "文件不存在: %s" % p_path, module_name)

	var err := DirAccess.remove_absolute(p_path)
	if err != OK:
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "删除文件失败: %s" % p_path, module_name)
	return GF_OperationResult.ok()


# ============================================================
# 文本读写
# ============================================================

## 读取文本文件
func read_text(p_path: String) -> GF_OperationResult:
	if not file_exists(p_path):
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_NOT_FOUND,
			"文件不存在: %s" % p_path,
			module_name
		)

	var fa := FileAccess.open(p_path, FileAccess.READ)
	if fa == null:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"无法打开文件: %s" % p_path,
			module_name
		)

	var content := fa.get_as_text()
	fa.close()
	return GF_OperationResult.ok(content)


## 写入文本文件（覆盖模式）
func write_text(p_path: String, p_content: String) -> GF_OperationResult:
	# 确保父目录存在
	var dir := p_path.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result

	var fa := FileAccess.open(p_path, FileAccess.WRITE)
	if fa == null:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"无法写入文件: %s" % p_path,
			module_name
		)

	fa.store_string(p_content)
	fa.close()
	return GF_OperationResult.ok()


## 追加写入文本文件（创建或追加模式）
func append_text(p_path: String, p_content: String) -> GF_OperationResult:
	var dir := p_path.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result

	var fa := FileAccess.open(p_path, FileAccess.READ_WRITE)
	if fa == null:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"无法打开文件: %s" % p_path,
			module_name
		)

	fa.seek_end()
	fa.store_string(p_content)
	fa.close()
	return GF_OperationResult.ok()


# ============================================================
# JSON 读写
# ============================================================

## 读取并解析 JSON 文件，返回 Dictionary
func read_json(p_path: String) -> GF_OperationResult:
	var text_result := read_text(p_path)
	if text_result.is_fail():
		return text_result

	var text: String = text_result.data
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"JSON 解析失败: %s" % p_path,
			module_name
		)
	return GF_OperationResult.ok(parsed)


## 将 Dictionary 写入 JSON 文件
func write_json(p_path: String, p_data: Dictionary, p_indent: String = "\t") -> GF_OperationResult:
	var text := JSON.stringify(p_data, p_indent)
	if text.is_empty():
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_IO,
			"JSON 序列化失败: %s" % p_path,
			module_name
		)
	return write_text(p_path, text)
