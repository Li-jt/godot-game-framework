# tests/helpers/fake_file_system_service.gd
class_name GF_FakeFileSystemService
extends GF_FileSystemService

var _files: Dictionary = {}
var _jsons: Dictionary = {}
var _dirs: Array[String] = []


func file_exists(p_path: String) -> bool:
	return _files.has(p_path) or _jsons.has(p_path)


func dir_exists(p_path: String) -> bool:
	var normalized := p_path.rstrip("/") + "/"
	return _dirs.has(normalized) or _dirs.has(p_path.rstrip("/"))


func ensure_dir(p_path: String) -> GF_OperationResult:
	var normalized := p_path.rstrip("/") + "/"
	if not _dirs.has(normalized):
		_dirs.append(normalized)
	return GF_OperationResult.ok()


func list_files(p_dir: String) -> GF_OperationResult:
	var result: Array[String] = []
	var prefix := p_dir.rstrip("/") + "/"
	for path in _files:
		if path.begins_with(prefix):
			result.append(path.trim_prefix(prefix))
	for path in _jsons:
		if path.begins_with(prefix):
			var fname = path.trim_prefix(prefix)
			if not result.has(fname):
				result.append(fname)
	return GF_OperationResult.ok(result)


func read_text(p_path: String) -> GF_OperationResult:
	if not _files.has(p_path):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "file not found: %s" % p_path, "FakeFS")
	return GF_OperationResult.ok(_files[p_path])


func write_text(p_path: String, p_content: String) -> GF_OperationResult:
	_files[p_path] = p_content
	return GF_OperationResult.ok()


func write_text_atomic(p_path: String, p_content: String) -> GF_OperationResult:
	_files[p_path] = p_content
	return GF_OperationResult.ok()


func read_json(p_path: String) -> GF_OperationResult:
	if _jsons.has(p_path):
		return GF_OperationResult.ok(_jsons[p_path])
	if _files.has(p_path):
		var parsed = JSON.parse_string(_files[p_path])
		if parsed is Dictionary:
			return GF_OperationResult.ok(parsed)
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "JSON parse error: %s" % p_path, "FakeFS")
	return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "file not found: %s" % p_path, "FakeFS")


func write_json(p_path: String, p_data: Dictionary, p_indent: String = "\t") -> GF_OperationResult:
	_jsons[p_path] = p_data
	return GF_OperationResult.ok()


func delete_file(p_path: String) -> GF_OperationResult:
	_files.erase(p_path)
	_jsons.erase(p_path)
	return GF_OperationResult.ok()


func backup_file(p_path: String) -> GF_OperationResult:
	if _files.has(p_path):
		_files[p_path + ".bak"] = _files[p_path]
	if _jsons.has(p_path):
		_jsons[p_path + ".bak"] = _jsons[p_path]
	return GF_OperationResult.ok()


func preset_text(p_path: String, p_content: String) -> void:
	_files[p_path] = p_content


func preset_json(p_path: String, p_data: Dictionary) -> void:
	_jsons[p_path] = p_data
