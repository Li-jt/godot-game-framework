# tests/unit/core/test_operation_result.gd
## GF_OperationResult 单元测试。
## 所有框架 API 的返回值基础，此模块必须先测。
extends GutTest


# ============================================================
# 成功结果
# ============================================================

func test_ok_returns_success_true() -> void:
	var r := GF_OperationResult.ok()
	assert_true(r.is_ok(), "ok() should return success")
	assert_false(r.is_fail(), "ok() should not be fail")


func test_ok_stores_data() -> void:
	var data := {"key": "value"}
	var r := GF_OperationResult.ok(data)
	assert_eq(r.data, data)


func test_ok_default_status_is_200() -> void:
	var r := GF_OperationResult.ok()
	assert_eq(r.status_code, 200)
	assert_true(r.success)


func test_created_returns_201() -> void:
	var r := GF_OperationResult.created()
	assert_eq(r.status_code, 201)
	assert_true(r.is_ok())


func test_created_stores_data() -> void:
	var data := [1, 2, 3]
	var r := GF_OperationResult.created(data)
	assert_eq(r.data, data)


# ============================================================
# 失败结果
# ============================================================

func test_fail_sets_correct_code() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "实体不存在", "TestModule")
	assert_eq(r.status_code, 404)


func test_fail_creates_error_info() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_VALIDATION, "校验失败", "TestModule")
	assert_not_null(r.error)
	assert_eq(r.error.message, "校验失败")
	assert_eq(r.error.code, "422")


func test_fail_sets_source_module() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "内部错误", "MyModule")
	assert_eq(r.error.source_module, "MyModule")


func test_fail_is_not_ok() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "not found")
	assert_false(r.is_ok())
	assert_true(r.is_fail())


func test_fail_empty_source_module() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_IO, "IO 错误")
	assert_eq(r.error.source_module, "")


# ============================================================
# 判断方法
# ============================================================

func test_is_ok_and_is_fail_opposite() -> void:
	var ok := GF_OperationResult.ok()
	assert_true(ok.is_ok())
	assert_false(ok.is_fail())

	var fail := GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "not found")
	assert_false(fail.is_ok())
	assert_true(fail.is_fail())


# ============================================================
# with_context
# ============================================================

func test_with_context_appends_to_error() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "请求无效", "TestModule")
	r.with_context("entity_id", 42)
	assert_eq(r.error.context["entity_id"], 42)


func test_with_context_chainable() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "bad")
	r.with_context("a", 1).with_context("b", 2)
	assert_eq(r.error.context["a"], 1)
	assert_eq(r.error.context["b"], 2)


func test_with_context_on_ok_no_error() -> void:
	var r := GF_OperationResult.ok()
	r.with_context("key", "value")
	assert_null(r.error)


# ============================================================
# wrap
# ============================================================

func test_wrap_preserves_status_and_sets_cause() -> void:
	var original := GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "原始错误", "OriginalModule")
	var wrapped := GF_OperationResult.wrap(original, "WrapperModule", "包装后的错误")

	assert_eq(wrapped.status_code, 404)
	assert_eq(wrapped.error.source_module, "WrapperModule")
	assert_eq(wrapped.error.message, "包装后的错误")
	assert_not_null(wrapped.error.cause)
	assert_eq(wrapped.error.cause, original.error)


# ============================================================
# root_cause
# ============================================================

func test_root_cause_traverses_nested() -> void:
	var a := GF_OperationResult.fail(GF_OperationResult.ERR_IO, "最底层错误", "A")
	var b := GF_OperationResult.wrap(a, "B", "中层包装")
	var c := GF_OperationResult.wrap(b, "C", "顶层包装")

	var root := c.root_cause()
	assert_not_null(root)
	assert_eq(root.message, "最底层错误")
	assert_eq(root.source_module, "A")


func test_root_cause_returns_null_when_no_cause() -> void:
	var ok := GF_OperationResult.ok()
	var root := ok.root_cause()
	assert_null(root)


func test_root_cause_returns_single_error() -> void:
	var r := GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "单层错误", "X")
	var root := r.root_cause()
	assert_eq(root.message, "单层错误")


# ============================================================
# status_text
# ============================================================

var status_code_params := [
	[200, "OK"],
	[201, "Created"],
	[202, "Accepted"],
	[400, "Bad Request"],
	[401, "Unauthorized"],
	[403, "Forbidden"],
	[404, "Not Found"],
	[409, "Conflict"],
	[422, "Validation Failed"],
	[428, "Precondition Failed"],
	[500, "Internal Error"],
	[501, "Config Error"],
	[502, "IO Error"],
	[503, "Network Error"],
	[504, "Timeout"],
	[505, "Disposed"],
	[506, "Migration Error"],
]


func test_status_text_for_all_codes(param: Array = use_parameters(status_code_params)) -> void:
	var code: int = param[0]
	var expected: String = param[1]
	var r := GF_OperationResult.fail(code, "test")
	assert_eq(r.status_text(), expected)


func test_status_text_for_unknown_code() -> void:
	var r := GF_OperationResult.fail(999, "ninety nine nine")
	assert_eq(r.status_text(), "Unknown")
