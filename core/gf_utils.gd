## GF_Utils
## 通用工具函数集。纯静态方法，无状态、无依赖，直接 GF_Utils.xxx() 调用。
class_name GF_Utils
extends RefCounted


# ============================================================
# 路径 / 文件
# ============================================================

## 取文件名（含扩展名）。"res://data/config.json" → "config.json"
static func file_name(p_path: String) -> String:
	return p_path.get_file()


## 取扩展名（不含点）。"res://data/config.json" → "json"
static func file_ext(p_path: String) -> String:
	return p_path.get_extension()


## 取不含扩展名的文件名。"res://data/config.json" → "config"
static func base_name(p_path: String) -> String:
	return p_path.get_file().trim_suffix("." + p_path.get_extension())


## 取父目录路径。"res://data/config.json" → "res://data/"
static func parent_dir(p_path: String) -> String:
	return p_path.get_base_dir()


## 替换扩展名。change_ext("res://data.json", "cfg") → "res://data.cfg"
static func change_ext(p_path: String, p_new_ext: String) -> String:
	var base := base_name(p_path)
	var dir := parent_dir(p_path)
	return dir.path_join(base + "." + p_new_ext)


## 是否是 .gd 脚本文件
static func is_gd_script(p_path: String) -> bool:
	return file_ext(p_path) == "gd"


## 是否是 .tscn 场景文件
static func is_scene(p_path: String) -> bool:
	return file_ext(p_path) == "tscn"


## 是否是图片文件（常见格式）
static func is_image(p_path: String) -> bool:
	var ext := file_ext(p_path).to_lower()
	return ext in ["png", "jpg", "jpeg", "webp", "bmp", "svg", "tga"]


## 是否是音频文件
static func is_audio(p_path: String) -> bool:
	var ext := file_ext(p_path).to_lower()
	return ext in ["ogg", "mp3", "wav", "import"]


# ============================================================
# 字符串
# ============================================================

## 格式化字节大小。format_size(1024000) → "1.0 MB"
static func format_size(p_bytes: int) -> String:
	var units := ["B", "KB", "MB", "GB"]
	var size: float = p_bytes
	var unit_idx: int = 0
	while size >= 1024.0 and unit_idx < units.size() - 1:
		size /= 1024.0
		unit_idx += 1
	if unit_idx == 0:
		return "%d %s" % [p_bytes, units[unit_idx]]
	return "%.1f %s" % [size, units[unit_idx]]


## 格式化秒数为 mm:ss。format_time(125) → "02:05"
static func format_time(p_seconds: float) -> String:
	var total := int(p_seconds)
	var mins := total / 60
	var secs := total % 60
	return "%02d:%02d" % [mins, secs]


## 格式化秒数为 hh:mm:ss
static func format_time_long(p_seconds: float) -> String:
	var total := int(p_seconds)
	var hrs := total / 3600
	var mins := (total % 3600) / 60
	var secs := total % 60
	return "%02d:%02d:%02d" % [hrs, mins, secs]


## 截断字符串。p_max_len 不含省略号的长度。truncate("很长很长", 3) → "很长..."
static func truncate(p_text: String, p_max_len: int, p_ellipsis: String = "...") -> String:
	if p_text.length() <= p_max_len:
		return p_text
	return p_text.substr(0, p_max_len) + p_ellipsis


## PascalCase 转 snake_case。"MyClassName" → "my_class_name"、"GF_UIService" → "gf_ui_service"
static func to_snake_case(p_name: String) -> String:
	var result := ""
	for i in p_name.length():
		var ch := p_name[i]
		if ch == "_":
			result += "_"
			continue
		var is_upper := ch >= "A" and ch <= "Z"
		var prev_is_lower := i > 0 and p_name[i - 1] >= "a" and p_name[i - 1] <= "z"
		var next_is_lower := i + 1 < p_name.length() and p_name[i + 1] >= "a" and p_name[i + 1] <= "z"
		# 在以下情况前插入下划线：前一个字符是小写，或者后面紧跟小写且前面是大写
		if i > 0 and is_upper and p_name[i - 1] != "_" and result.length() > 0:
			if prev_is_lower or next_is_lower:
				result += "_"
		result += ch.to_lower()
	return result


## snake_case 转 PascalCase。"my_class_name" → "MyClassName"
static func to_pascal_case(p_name: String) -> String:
	var result := ""
	for i in p_name.length():
		var ch := p_name[i]
		if ch == "_":
			continue
		if i == 0 or p_name[i - 1] == "_":
			result += ch.to_upper()
		else:
			result += ch
	return result


## 检查字符串是否包含指定子串列表中的任意一个
static func contains_any(p_text: String, p_substrings: Array[String]) -> bool:
	for sub in p_substrings:
		if sub in p_text:
			return true
	return false


## 字符串是否为空（null 或空白）
static func is_empty(p_text: String) -> bool:
	return p_text.is_empty()


## 字符串是否有实际内容（非空且非空白）
static func is_blank(p_text: String) -> bool:
	return p_text.strip_edges().is_empty()


# ============================================================
# 数组
# ============================================================

## 随机取一个元素
static func pick_random(p_array: Array) -> Variant:
	if p_array.is_empty():
		return null
	return p_array[randi() % p_array.size()]


## Fisher-Yates 洗牌（原地修改，同时返回引用）
static func shuffle(p_array: Array) -> Array:
	for i in range(p_array.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = p_array[i]
		p_array[i] = p_array[j]
		p_array[j] = tmp
	return p_array


## 去重（保持原始顺序）
static func unique(p_array: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for item in p_array:
		var key := str(item)
		if not seen.has(key):
			seen[key] = true
			result.append(item)
	return result


## 按 size 切分成多个子数组。chunk([1,2,3,4,5], 2) → [[1,2], [3,4], [5]]
static func chunk(p_array: Array, p_size: int) -> Array:
	var result: Array = []
	for i in range(0, p_array.size(), p_size):
		var end := mini(i + p_size, p_array.size())
		result.append(p_array.slice(i, end))
	return result


## 过滤出满足条件的元素
static func filter(p_array: Array, p_predicate: Callable) -> Array:
	var result: Array = []
	for item in p_array:
		if p_predicate.call(item):
			result.append(item)
	return result


## 查找第一个满足条件的元素，找不到返回 null
static func find(p_array: Array, p_predicate: Callable) -> Variant:
	for item in p_array:
		if p_predicate.call(item):
			return item
	return null


## 取前 n 个元素
static func first(p_array: Array, p_count: int = 1) -> Variant:
	if p_count == 1:
		return p_array[0] if p_array.size() > 0 else null
	return p_array.slice(0, mini(p_count, p_array.size()))


## 取后 n 个元素
static func last(p_array: Array, p_count: int = 1) -> Variant:
	if p_count == 1:
		return p_array[-1] if p_array.size() > 0 else null
	var start := maxi(0, p_array.size() - p_count)
	return p_array.slice(start, p_array.size())


## 按 key 字段分组。group_by([{type:"a"}, {type:"b"}, {type:"a"}], "type") → {"a":[...], "b":[...]}
static func group_by(p_array: Array, p_key: String) -> Dictionary:
	var result: Dictionary = {}
	for item in p_array:
		var key: String = str(item.get(p_key)) if item is Dictionary else ""
		if not result.has(key):
			result[key] = []
		result[key].append(item)
	return result


# ============================================================
# 字典
# ============================================================

## 浅合并 — b 覆盖 a 的同名键
static func dict_merge(p_a: Dictionary, p_b: Dictionary) -> Dictionary:
	var result := p_a.duplicate()
	for key in p_b:
		result[key] = p_b[key]
	return result


## 深度合并嵌套字典 — b 覆盖 a 的同名键，嵌套字典递归合并
static func dict_deep_merge(p_a: Dictionary, p_b: Dictionary) -> Dictionary:
	var result := p_a.duplicate()
	for key in p_b:
		if result.has(key) and result[key] is Dictionary and p_b[key] is Dictionary:
			result[key] = dict_deep_merge(result[key], p_b[key])
		else:
			result[key] = p_b[key]
	return result


## 从字典中摘取指定的 key 组成新字典
static func dict_pick(p_dict: Dictionary, p_keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key in p_keys:
		if p_dict.has(key):
			result[key] = p_dict[key]
	return result


## 从字典中排除指定的 key 组成新字典
static func dict_omit(p_dict: Dictionary, p_keys: Array) -> Dictionary:
	var result := p_dict.duplicate()
	for key in p_keys:
		result.erase(key)
	return result


# ============================================================
# 随机
# ============================================================

## 加权随机选择。weights 为权重数组，与 items 等长。
## weighted_pick(["a", "b", "c"], [1, 2, 7]) → 大概率返回 "c"
static func weighted_pick(p_items: Array, p_weights: Array) -> Variant:
	if p_items.is_empty() or p_items.size() != p_weights.size():
		return null

	var total: float = 0.0
	for w in p_weights:
		total += float(w)
	if total <= 0.0:
		return null

	var roll := randf() * total
	var cumulative: float = 0.0
	for i in p_items.size():
		cumulative += float(p_weights[i])
		if roll <= cumulative:
			return p_items[i]
	return p_items[-1]


## 百分比概率。chance(30) → 30% 概率返回 true
static func chance(p_percent: float) -> bool:
	return randf() * 100.0 < p_percent


## 含两端边界的随机整数。rand_range_int(1, 6) → 1~6 之间的整数
static func rand_range_int(p_min: int, p_max: int) -> int:
	return randi() % (p_max - p_min + 1) + p_min


## 在范围内随机浮点数。rand_range_float(0.0, 1.0)
static func rand_range_float(p_min: float, p_max: float) -> float:
	return randf() * (p_max - p_min) + p_min


# ============================================================
# 数据转换
# ============================================================

## Vector2 → Dictionary
static func vec2_to_dict(p_vec: Vector2) -> Dictionary:
	return {"x": p_vec.x, "y": p_vec.y}


## Dictionary → Vector2
static func dict_to_vec2(p_dict: Dictionary) -> Vector2:
	return Vector2(float(p_dict.get("x", 0.0)), float(p_dict.get("y", 0.0)))


## Vector3 → Dictionary
static func vec3_to_dict(p_vec: Vector3) -> Dictionary:
	return {"x": p_vec.x, "y": p_vec.y, "z": p_vec.z}


## Dictionary → Vector3
static func dict_to_vec3(p_dict: Dictionary) -> Vector3:
	return Vector3(
		float(p_dict.get("x", 0.0)),
		float(p_dict.get("y", 0.0)),
		float(p_dict.get("z", 0.0))
	)


## Color → 十六进制字符串。"#FF0000"
static func color_to_hex(p_color: Color) -> String:
	return "#%02X%02X%02X" % [
		int(p_color.r * 255),
		int(p_color.g * 255),
		int(p_color.b * 255),
	]


## 十六进制字符串 → Color。hex_to_color("#FF0000") → Color.RED
static func hex_to_color(p_hex: String) -> Color:
	var h := p_hex.strip_edges()
	if h.begins_with("#"):
		h = h.substr(1)
	if h.length() < 6:
		return Color.WHITE
	return Color(
		h.substr(0, 2).hex_to_int() / 255.0,
		h.substr(2, 2).hex_to_int() / 255.0,
		h.substr(4, 2).hex_to_int() / 255.0,
	)


## Rect2 → Dictionary
static func rect2_to_dict(p_rect: Rect2) -> Dictionary:
	return {
		"x": p_rect.position.x,
		"y": p_rect.position.y,
		"w": p_rect.size.x,
		"h": p_rect.size.y,
	}


## Dictionary → Rect2
static func dict_to_rect2(p_dict: Dictionary) -> Rect2:
	return Rect2(
		float(p_dict.get("x", 0.0)),
		float(p_dict.get("y", 0.0)),
		float(p_dict.get("w", 0.0)),
		float(p_dict.get("h", 0.0)),
	)


## JS 风格模板字符串。将 ${key} 替换为字典中对应的值。
## [codeblock]s("实体 ${id} 已销毁, 数量: ${n}", {"id": 42, "n": 5})[/codeblock] → "实体 42 已销毁, 数量: 5"
static func s(p_template: String, p_vars: Dictionary) -> String:
	var result := p_template
	for key in p_vars:
		result = result.replace("${%s}" % str(key), str(p_vars[key]))
	return result