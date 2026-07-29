# tests/unit/engine/test_file_system_service.gd
## GF_FileSystemService 单元测试（使用 GF_FakeFileSystemService）。
## 覆盖文件读写、JSON、原子写入、备份。
extends GutTest

var _fs: GF_FakeFileSystemService


func before_each() -> void:
	_fs = GF_FakeFileSystemService.new()
	_fs.module_name = "FakeFS"
	_fs.init_module()


func after_each() -> void:
	_fs = null


# ============================================================
# 文件存在性
# ============================================================

func test_file_exists_true_after_write() -> void:
	_fs.write_text("test.txt", "hello")
	assert_true(_fs.file_exists("test.txt"))


func test_file_exists_false_initially() -> void:
	assert_false(_fs.file_exists("nonexistent.txt"))


func test_dir_exists_true_after_ensure() -> void:
	_fs.ensure_dir("test_dir")
	assert_true(_fs.dir_exists("test_dir"))


# ============================================================
# 文本读写
# ============================================================

func test_write_and_read_text_roundtrip() -> void:
	var content := "hello world"
	_fs.write_text("test.txt", content)
	var result := _fs.read_text("test.txt")
	assert_true(result.is_ok())
	assert_eq(result.data, content)


func test_read_text_fails_for_missing() -> void:
	var result := _fs.read_text("nonexistent.txt")
	assert_true(result.is_fail())


func test_write_text_atomic_works() -> void:
	_fs.write_text_atomic("test.json", "{}")
	assert_true(_fs.file_exists("test.json"))


# ============================================================
# JSON 读写
# ============================================================

func test_write_and_read_json_roundtrip() -> void:
	var data := {"name": "test", "value": 42}
	_fs.write_json("config.json", data)
	var result := _fs.read_json("config.json")
	assert_true(result.is_ok())
	assert_eq(result.data, data)


func test_read_json_fails_for_missing() -> void:
	var result := _fs.read_json("missing.json")
	assert_true(result.is_fail())


# ============================================================
# 文件操作
# ============================================================

func test_delete_file_removes() -> void:
	_fs.write_text("temp.txt", "temp")
	_fs.delete_file("temp.txt")
	assert_false(_fs.file_exists("temp.txt"))


func test_backup_file_creates_backup() -> void:
	_fs.write_text("original.txt", "data")
	_fs.backup_file("original.txt")
	assert_true(_fs.file_exists("original.txt.bak"))


func test_list_files_returns_names() -> void:
	_fs.ensure_dir("dir")
	_fs.write_text("dir/a.txt", "")
	_fs.write_text("dir/b.txt", "")

	var result := _fs.list_files("dir")
	assert_true(result.is_ok())
	var files: Array = result.data
	assert_eq(files.size(), 2)


# ============================================================
# 预设辅助
# ============================================================

func test_preset_text_sets_content() -> void:
	_fs.preset_text("path/to/file.txt", "preset content")
	var result := _fs.read_text("path/to/file.txt")
	assert_eq(result.data, "preset content")


func test_preset_json_sets_content() -> void:
	_fs.preset_json("path/config.json", {"key": "value"})
	var result := _fs.read_json("path/config.json")
	assert_eq(result.data, {"key": "value"})
