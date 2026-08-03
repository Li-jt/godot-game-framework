# tests/unit/core/test_utils.gd
## GF_Utils 单元测试
extends GutTest


# ============================================================
# 路径 / 文件
# ============================================================

func test_file_name() -> void:
	assert_eq(GF_Utils.file_name("res://data/config.json"), "config.json")
	assert_eq(GF_Utils.file_name("config.gd"), "config.gd")


func test_file_ext() -> void:
	assert_eq(GF_Utils.file_ext("res://data/config.json"), "json")
	assert_eq(GF_Utils.file_ext("script.gd"), "gd")


func test_base_name() -> void:
	assert_eq(GF_Utils.base_name("res://data/config.json"), "config")
	assert_eq(GF_Utils.base_name("health_component.gd"), "health_component")


func test_parent_dir() -> void:
	assert_eq(GF_Utils.parent_dir("res://data/config.json"), "res://data")
	assert_eq(GF_Utils.parent_dir("res://data/"), "res://data")


func test_change_ext() -> void:
	assert_eq(GF_Utils.change_ext("res://data.json", "cfg"), "res://data.cfg")
	assert_eq(GF_Utils.change_ext("res://a/b/c.gd", "gd.uid"), "res://a/b/c.gd.uid")


func test_is_gd_script() -> void:
	assert_true(GF_Utils.is_gd_script("player.gd"))
	assert_false(GF_Utils.is_gd_script("scene.tscn"))


func test_is_scene() -> void:
	assert_true(GF_Utils.is_scene("main.tscn"))
	assert_false(GF_Utils.is_scene("player.gd"))


func test_is_image() -> void:
	assert_true(GF_Utils.is_image("icon.png"))
	assert_true(GF_Utils.is_image("bg.jpg"))
	assert_true(GF_Utils.is_image("sprite.webp"))
	assert_false(GF_Utils.is_image("script.gd"))


func test_is_audio() -> void:
	assert_true(GF_Utils.is_audio("bgm.ogg"))
	assert_true(GF_Utils.is_audio("sfx.wav"))
	assert_true(GF_Utils.is_audio("voice.mp3"))
	assert_false(GF_Utils.is_audio("icon.png"))


# ============================================================
# 字符串
# ============================================================

func test_format_size_bytes() -> void:
	assert_eq(GF_Utils.format_size(0), "0 B")
	assert_eq(GF_Utils.format_size(500), "500 B")


func test_format_size_kb() -> void:
	assert_string_contains(GF_Utils.format_size(1024), "KB")


func test_format_size_mb() -> void:
	assert_string_contains(GF_Utils.format_size(1048576), "MB")


func test_format_time() -> void:
	assert_eq(GF_Utils.format_time(0), "00:00")
	assert_eq(GF_Utils.format_time(65), "01:05")
	assert_eq(GF_Utils.format_time(125), "02:05")
	assert_eq(GF_Utils.format_time(3599), "59:59")


func test_format_time_long() -> void:
	assert_eq(GF_Utils.format_time_long(3661), "01:01:01")
	assert_eq(GF_Utils.format_time_long(0), "00:00:00")


func test_truncate() -> void:
	assert_eq(GF_Utils.truncate("Hello World", 5), "Hello...")
	assert_eq(GF_Utils.truncate("Hi", 5), "Hi")
	assert_eq(GF_Utils.truncate("abc", 3, "…"), "abc")


func test_to_snake_case() -> void:
	assert_eq(GF_Utils.to_snake_case("MyClass"), "my_class")
	assert_eq(GF_Utils.to_snake_case("HealthComponent"), "health_component")


func test_to_pascal_case() -> void:
	assert_eq(GF_Utils.to_pascal_case("my_class"), "MyClass")
	assert_eq(GF_Utils.to_pascal_case("health_component"), "HealthComponent")


func test_contains_any() -> void:
	assert_true(GF_Utils.contains_any("hello world", ["hello", "bye"]))
	assert_false(GF_Utils.contains_any("hello world", ["foo", "bar"]))


func test_is_empty() -> void:
	assert_true(GF_Utils.is_empty(""))
	assert_false(GF_Utils.is_empty("hello"))


func test_is_blank() -> void:
	assert_true(GF_Utils.is_blank("   "))
	assert_true(GF_Utils.is_blank("\t\n"))
	assert_false(GF_Utils.is_blank(" hello "))


# ============================================================
# 数组
# ============================================================

func test_pick_random() -> void:
	var arr := [1, 2, 3]
	var picked: int = GF_Utils.pick_random(arr)
	assert_true(picked in arr)


func test_pick_random_empty() -> void:
	assert_null(GF_Utils.pick_random([]))


func test_shuffle() -> void:
	var arr := [1, 2, 3, 4, 5]
	var original := arr.duplicate()
	GF_Utils.shuffle(arr)
	assert_eq(arr.size(), 5)
	# 元素应该都在（只是顺序可能变了）
	for item in original:
		assert_true(item in arr)


func test_unique() -> void:
	var result: Array = GF_Utils.unique([1, 2, 2, 3, 3, 3, 1])
	assert_eq(result.size(), 3)
	assert_eq(result[0], 1)
	assert_eq(result[1], 2)
	assert_eq(result[2], 3)


func test_chunk() -> void:
	var result: Array = GF_Utils.chunk([1, 2, 3, 4, 5], 2)
	assert_eq(result.size(), 3)
	assert_eq(result[0], [1, 2])
	assert_eq(result[1], [3, 4])
	assert_eq(result[2], [5])


func test_filter() -> void:
	var result: Array = GF_Utils.filter([1, 2, 3, 4, 5], func(x): return x > 3)
	assert_eq(result, [4, 5])


func test_find() -> void:
	var result: int = GF_Utils.find([1, 2, 3, 4], func(x): return x > 2)
	assert_eq(result, 3)


func test_find_not_found() -> void:
	assert_null(GF_Utils.find([1, 2], func(x): return x > 5))


func test_first() -> void:
	assert_eq(GF_Utils.first([10, 20, 30]), 10)
	assert_eq(GF_Utils.first([10, 20, 30], 2), [10, 20])
	assert_null(GF_Utils.first([]))


func test_last() -> void:
	assert_eq(GF_Utils.last([10, 20, 30]), 30)
	assert_eq(GF_Utils.last([10, 20, 30], 2), [20, 30])
	assert_null(GF_Utils.last([]))


func test_group_by() -> void:
	var data := [
		{"type": "fruit", "name": "apple"},
		{"type": "fruit", "name": "banana"},
		{"type": "veg", "name": "carrot"},
	]
	var result: Dictionary = GF_Utils.group_by(data, "type")
	assert_eq(result["fruit"].size(), 2)
	assert_eq(result["veg"].size(), 1)


# ============================================================
# 字典
# ============================================================

func test_dict_merge() -> void:
	var a := {"x": 1, "y": 2}
	var b := {"y": 99, "z": 3}
	var result: Dictionary = GF_Utils.dict_merge(a, b)
	assert_eq(result["x"], 1)
	assert_eq(result["y"], 99)  # b 覆盖 a
	assert_eq(result["z"], 3)


func test_dict_deep_merge() -> void:
	var a := {"nested": {"a": 1, "b": 2}, "x": 10}
	var b := {"nested": {"b": 99, "c": 3}}
	var result: Dictionary = GF_Utils.dict_deep_merge(a, b)
	assert_eq(result["x"], 10)
	assert_eq(result["nested"]["a"], 1)
	assert_eq(result["nested"]["b"], 99)
	assert_eq(result["nested"]["c"], 3)


func test_dict_pick() -> void:
	var result: Dictionary = GF_Utils.dict_pick({"a": 1, "b": 2, "c": 3}, ["a", "c"])
	assert_eq(result.size(), 2)
	assert_eq(result["a"], 1)
	assert_false(result.has("b"))
	assert_eq(result["c"], 3)


func test_dict_omit() -> void:
	var result: Dictionary = GF_Utils.dict_omit({"a": 1, "b": 2, "c": 3}, ["b"])
	assert_eq(result.size(), 2)
	assert_eq(result["a"], 1)
	assert_eq(result["c"], 3)
	assert_false(result.has("b"))


# ============================================================
# 随机
# ============================================================

func test_chance_always() -> void:
	assert_true(GF_Utils.chance(100.0))


func test_chance_never() -> void:
	assert_false(GF_Utils.chance(0.0))


func test_rand_range_int() -> void:
	for _i in 10:
		var val := GF_Utils.rand_range_int(1, 6)
		assert_true(val >= 1 and val <= 6)


func test_rand_range_float() -> void:
	for _i in 10:
		var val := GF_Utils.rand_range_float(0.0, 1.0)
		assert_true(val >= 0.0 and val <= 1.0)


func test_weighted_pick() -> void:
	# 全权重在一个元素，应总是返回它
	var result: String = GF_Utils.weighted_pick(["a", "b", "c"], [0, 1, 0])
	assert_eq(result, "b")


func test_weighted_pick_empty() -> void:
	assert_null(GF_Utils.weighted_pick([], []))


# ============================================================
# 数据转换
# ============================================================

func test_vec2_to_dict_and_back() -> void:
	var v := Vector2(3.0, 7.0)
	var d: Dictionary = GF_Utils.vec2_to_dict(v)
	assert_eq(d["x"], 3.0)
	assert_eq(d["y"], 7.0)
	var v2 := GF_Utils.dict_to_vec2(d)
	assert_almost_eq(v2.x, v.x, 0.001)
	assert_almost_eq(v2.y, v.y, 0.001)


func test_to_snake_case_gf_prefix() -> void:
	assert_eq(GF_Utils.to_snake_case("GF_UIService"), "gf_ui_service")
	assert_eq(GF_Utils.to_snake_case("GF_AppBootstrap"), "gf_app_bootstrap")


func test_vec3_roundtrip() -> void:
	var v := Vector3(1.0, 2.0, 3.0)
	var d: Dictionary = GF_Utils.vec3_to_dict(v)
	var v2 := GF_Utils.dict_to_vec3(d)
	assert_eq(v2, v)


func test_color_to_hex() -> void:
	var hex := GF_Utils.color_to_hex(Color(1.0, 0.0, 0.0))
	assert_eq(hex, "#FF0000")


func test_hex_to_color() -> void:
	var c := GF_Utils.hex_to_color("#00FF00")
	assert_eq(c, Color.GREEN)


func test_rect2_roundtrip() -> void:
	var r := Rect2(10, 20, 100, 200)
	var d: Dictionary = GF_Utils.rect2_to_dict(r)
	var r2 := GF_Utils.dict_to_rect2(d)
	assert_eq(r2, r)
