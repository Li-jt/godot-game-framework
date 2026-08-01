# tests/unit/input/test_input_binding.gd
extends GutTest


func test_matches_signal_by_source_and_code() -> void:
	var binding := GF_InputBinding.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE)
	var sig := GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE)
	assert_true(binding.matches_signal(sig))


func test_matches_signal_mismatch_source() -> void:
	var binding := GF_InputBinding.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE)
	var sig := GF_InputRawSignal.new(GF_InputBinding.Source.MOUSE_BUTTON, KEY_SPACE)
	assert_false(binding.matches_signal(sig))


func test_matches_signal_mismatch_code() -> void:
	var binding := GF_InputBinding.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE)
	var sig := GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_A)
	assert_false(binding.matches_signal(sig))


func test_matches_signal_device_wildcard() -> void:
	var binding := GF_InputBinding.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE)
	var sig := GF_InputRawSignal.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE, true, 0.0, Vector2.INF, 16)
	assert_true(binding.matches_signal(sig))


func test_matches_signal_device_filter() -> void:
	var binding := GF_InputBinding.new(GF_InputBinding.Source.GAMEPAD_BUTTON, 0, 1.0, GF_InputBinding.Mode.IMPULSE, false, GF_InputBinding.Slot.PRIMARY, 0)
	var sig1 := GF_InputRawSignal.new(GF_InputBinding.Source.GAMEPAD_BUTTON, 0, true, 0.0, Vector2.INF, 0)
	assert_true(binding.matches_signal(sig1))
	var sig2 := GF_InputRawSignal.new(GF_InputBinding.Source.GAMEPAD_BUTTON, 0, true, 0.0, Vector2.INF, 1)
	assert_false(binding.matches_signal(sig2))


func test_to_dict_and_from_dict_roundtrip() -> void:
	var binding := GF_InputBinding.new(GF_InputBinding.Source.KEYBOARD, KEY_W)
	var d := binding.to_dict()
	var restored := GF_InputBinding.from_dict(d)
	assert_eq(restored.source, binding.source)
	assert_eq(restored.code, binding.code)


func test_duplicate_binding_independent() -> void:
	var original := GF_InputBinding.new(GF_InputBinding.Source.KEYBOARD, KEY_SPACE)
	var copy := original.duplicate_binding()
	copy.code = KEY_A
	assert_ne(original.code, copy.code)
