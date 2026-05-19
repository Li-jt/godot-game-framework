## FileSystemService
## 统一文件系统服务，封装 Godot FileAccess / DirAccess。
## 所有模块的文件读写、目录操作必须通过此服务，禁止直接使用 FileAccess。
##
## 所有方法返回 OperationResult：
##   - 成功时 data 为读取内容（String 或 Dictionary）
##   - 失败时 error 包含错误码和描述
class_name FileSystemService
extends ModuleLifecycle


func _on_init() -> OperationResult:
	return OperationResult.ok()


# ============================================================
# 存在性检查
# ============================================================

## 文件是否存在
func file_exists(p_path: String) -> bool:
	return FileAccess.file_exists(p_path)


## 目录是否存在
func dir_exists(p_path: String) -> bool:
	return DirAccess.dir_exists_absolute(p_path)


# ============================================================
# 目录操作
# ============================================================

## 确保目录存在（递归创建），返回 OperationResult
func ensure_dir(p_path: String) -> OperationResult:
	if dir_exists(p_path):
		return OperationResult.ok()

	var err := DirAccess.make_dir_recursive_absolute(p_path)
	if err != OK:
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"无法创建目录: %s (error %d)" % [p_path, err],
			module_name
		)
	return OperationResult.ok()


## 列出目录下的文件（仅文件名，不含子目录）。失败返回 fail
func list_files(p_dir: String) -> OperationResult:
	if not dir_exists(p_dir):
		return OperationResult.ok([])

	var files: Array = []
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return OperationResult.fail(OperationResult.ERR_IO, "无法打开目录: %s" % p_dir, module_name)

	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir():
			files.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return OperationResult.ok(files)


## 原子写入：先写临时文件 .tmp → rename 替换目标。写入过程中崩溃不会损坏原文件。
func write_text_atomic(p_path: String, p_content: String) -> OperationResult:
	var dir := p_path.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result

	var tmp_path := p_path + ".tmp"
	var fa := FileAccess.open(tmp_path, FileAccess.WRITE)
	if fa == null:
		return OperationResult.fail(OperationResult.ERR_IO, "无法写入临时文件: %s" % tmp_path, module_name)

	fa.store_string(p_content)
	fa.close()

	var err := DirAccess.rename_absolute(tmp_path, p_path)
	if err != OK:
		DirAccess.remove_absolute(tmp_path)
		return OperationResult.fail(OperationResult.ERR_IO, "原子写入 rename 失败: %s → %s" % [tmp_path, p_path], module_name)

	return OperationResult.ok()


## 备份文件：复制为 .bak。原文件不存在则跳过。
func backup_file(p_path: String) -> OperationResult:
	if not file_exists(p_path):
		return OperationResult.ok()
	return copy_file(p_path, p_path + ".bak")


## 复制文件。
func copy_file(p_from: String, p_to: String) -> OperationResult:
	if not file_exists(p_from):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "源文件不存在: %s" % p_from, module_name)
	var read_result := read_text(p_from)
	if read_result.is_fail():
		return read_result
	return write_text(p_to, read_result.data as String)


## 移动/重命名文件。
func move_file(p_from: String, p_to: String) -> OperationResult:
	if not file_exists(p_from):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "源文件不存在: %s" % p_from, module_name)
	var dir := p_to.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result
	var err := DirAccess.rename_absolute(p_from, p_to)
	if err != OK:
		return OperationResult.fail(OperationResult.ERR_IO, "移动文件失败: %s → %s" % [p_from, p_to], module_name)
	return OperationResult.ok()


## 删除文件
func delete_file(p_path: String) -> OperationResult:
	if not file_exists(p_path):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "文件不存在: %s" % p_path, module_name)

	var err := DirAccess.remove_absolute(p_path)
	if err != OK:
		return OperationResult.fail(OperationResult.ERR_IO, "删除文件失败: %s" % p_path, module_name)
	return OperationResult.ok()


# ============================================================
# 文本读写
# ============================================================

## 读取文本文件
func read_text(p_path: String) -> OperationResult:
	if not file_exists(p_path):
		return OperationResult.fail(
			OperationResult.ERR_NOT_FOUND,
			"文件不存在: %s" % p_path,
			module_name
		)

	var fa := FileAccess.open(p_path, FileAccess.READ)
	if fa == null:
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"无法打开文件: %s" % p_path,
			module_name
		)

	var content := fa.get_as_text()
	fa.close()
	return OperationResult.ok(content)


## 写入文本文件（覆盖模式）
func write_text(p_path: String, p_content: String) -> OperationResult:
	# 确保父目录存在
	var dir := p_path.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result

	var fa := FileAccess.open(p_path, FileAccess.WRITE)
	if fa == null:
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"无法写入文件: %s" % p_path,
			module_name
		)

	fa.store_string(p_content)
	fa.close()
	return OperationResult.ok()


## 追加写入文本文件（创建或追加模式）
func append_text(p_path: String, p_content: String) -> OperationResult:
	var dir := p_path.get_base_dir()
	var dir_result := ensure_dir(dir)
	if dir_result.is_fail():
		return dir_result

	var fa := FileAccess.open(p_path, FileAccess.READ_WRITE)
	if fa == null:
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"无法打开文件: %s" % p_path,
			module_name
		)

	fa.seek_end()
	fa.store_string(p_content)
	fa.close()
	return OperationResult.ok()


# ============================================================
# JSON 读写
# ============================================================

## 读取并解析 JSON 文件，返回 Dictionary
func read_json(p_path: String) -> OperationResult:
	var text_result := read_text(p_path)
	if text_result.is_fail():
		return text_result

	var text: String = text_result.data
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"JSON 解析失败: %s" % p_path,
			module_name
		)
	return OperationResult.ok(parsed)


## 将 Dictionary 写入 JSON 文件
func write_json(p_path: String, p_data: Dictionary, p_indent: String = "\t") -> OperationResult:
	var text := JSON.stringify(p_data, p_indent)
	if text.is_empty():
		return OperationResult.fail(
			OperationResult.ERR_IO,
			"JSON 序列化失败: %s" % p_path,
			module_name
		)
	return write_text(p_path, text)
