extends GutTest


func test_can_create_audio_bus() -> void:
	var script: GDScript = load("res://audio/audio_bus.gd")
	assert_not_null(script)
	var bus = script.new()
	bus.bus_name = "Test"
	bus.current_volume_db = -6.0
	assert_eq(bus.bus_name, "Test")
	assert_eq(bus.current_volume_db, -6.0)
	assert_false(bus.is_fading())


func test_is_fading_detects_active_fade() -> void:
	var script: GDScript = load("res://audio/audio_bus.gd")
	var bus = script.new()
	bus.fade_duration = 2.0
	bus.fade_elapsed = 0.5
	assert_true(bus.is_fading())


func test_fade_progress_returns_ratio() -> void:
	var script: GDScript = load("res://audio/audio_bus.gd")
	var bus = script.new()
	bus.fade_duration = 2.0
	bus.fade_elapsed = 1.0
	assert_eq(bus.fade_progress(), 0.5)
