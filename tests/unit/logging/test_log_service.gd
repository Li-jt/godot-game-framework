# tests/unit/logging/test_log_service.gd
extends GutTest

var _log: GF_LogService
var _sink: GF_MemoryLogSink


func before_each() -> void:
	_sink = GF_MemoryLogSink.new(100)
	_log = GF_LogService.new()
	_log.module_name = "TestLog"
	_log.init_module()
	_log.register_sink(_sink)


func after_each() -> void:
	_log = null
	_sink = null


func test_debug_logs_to_sink() -> void:
	_log.debug("Test", "debug message")
	var entries: Array = _sink.get_entries()
	assert_true(entries.size() > 0)


func test_info_logs_to_sink() -> void:
	_log.info("Test", "info message")
	var entries: Array = _sink.get_entries()
	assert_true(entries.size() > 0)


func test_warning_logs_to_sink() -> void:
	_log.warning("Test", "warning message")
	var entries: Array = _sink.get_entries()
	assert_true(entries.size() > 0)


func test_error_logs_to_sink() -> void:
	_log.error("Test", "error message")
	var entries: Array = _sink.get_entries()
	assert_true(entries.size() > 0)


func test_multiple_sinks_all_receive() -> void:
	var sink2 := GF_MemoryLogSink.new(100)
	_log.register_sink(sink2)
	_log.info("Test", "broadcast message")
	assert_true(_sink.get_entries().size() > 0)
	assert_true(sink2.get_entries().size() > 0)
