## InputContext
## 输入上下文。压入 InputService 的上下文栈后，限制可用动作。
##
## allowed_actions 为空时 = 所有已注册动作放行（默认 gameplay 模式）。
## 非空时 = 只有列表中的动作生效。
##
## 使用示例：
##   [codeblock]
##   # UI 上下文：只允许 UI 相关动作
##   var ui_ctx := InputContext.new()
##   ui_ctx.name = "ui"
##   ui_ctx.priority = 100
##   ui_ctx.allowed_actions = ["ui_accept", "ui_cancel"]
##   input_service.push_context(ui_ctx)
##   [/codeblock]
class_name InputContext
extends RefCounted

var name: String = ""
## 优先级，数字越大越优先
var priority: int = 0
## 允许的动作 ID 列表。空数组 = 允许所有已注册动作（放行模式）。
var allowed_actions: Array[String] = []
## 被屏蔽的动作 ID 列表。仅当 allowed_actions 为空时生效。
## 含 "*" 等效于 block_all_game_actions = true。
var blocked_action_ids: Array[String] = []
## 设为 true 则禁止所有游戏动作（block_all 优先于 allowed_actions）
var block_all_game_actions: bool = false
