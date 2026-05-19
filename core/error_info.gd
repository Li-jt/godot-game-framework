## ErrorInfo
## 统一错误信息结构。
## 所有模块的错误必须通过此结构传递，禁止只打 log 不返回错误对象。
##
## 使用场景：
##   - OperationResult.fail() 自动创建 ErrorInfo 实例
##   - 需要在调用链上层附加上下文时，直接修改 context 字典
class_name ErrorInfo
extends RefCounted

var code: String = ""           # 错误码，如 "ERR_CONFIG_MISSING_FIELD"
var message: String = ""        # 面向开发者的错误描述
var source_module: String = ""  # 错误来源模块名，便于定位
var original_error: String = "" # 原始异常信息，用于调试追踪
var context: Dictionary = {}    # 附加的上下文键值对，可自由扩展
## 原始错误引用，用于跨层包装时保留根因
var cause: ErrorInfo = null
