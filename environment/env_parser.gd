## EnvParser
## .env 文件解析器。
## 将 .env 格式的文本解析为 Dictionary（全部为 String 值），
## 后续由 AppConfigLoader 负责类型转换和路径映射。
class_name EnvParser
extends RefCounted

## 解析 .env 文件内容，返回 Dictionary[String, String]
## - 忽略以 # 开头的注释行
## - 忽略空行
## - 支持 KEY=VALUE 和 KEY="VALUE" 格式
## - 未赋值（仅 KEY）的行视为空字符串
static func parse(p_text: String) -> Dictionary:
	var result: Dictionary = {}

	for raw_line in p_text.split("\n"):
		var line := raw_line.strip_edges()

		# 跳过空行和注释
		if line.is_empty() or line.begins_with("#"):
			continue

		# 查找第一个 = 的位置
		var eq_pos := line.find("=")
		if eq_pos == -1:
			continue

		var key := line.substr(0, eq_pos).strip_edges()
		var value := line.substr(eq_pos + 1).strip_edges()

		# 去掉引号包裹（支持双引号和单引号）
		if value.begins_with('"') and value.ends_with('"'):
			value = value.substr(1, value.length() - 2)
		elif value.begins_with("'") and value.ends_with("'"):
			value = value.substr(1, value.length() - 2)

		if not key.is_empty():
			result[key] = value

	return result
