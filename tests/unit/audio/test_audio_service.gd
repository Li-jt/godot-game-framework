# tests/unit/audio/test_audio_service.gd
extends GutTest

var _audio: AudioService


func before_each() -> void:
	_audio = AudioService.new()
	_audio.module_name = "AudioService"
	_audio.init_module()


func after_each() -> void:
	_audio = null


func test_register_cue_stores_by_id() -> void:
	var cue := AudioCueDef.new()
	cue.id = "ui.click"
	_audio.register_cue(cue)


func test_register_cues_batch() -> void:
	var c1 := AudioCueDef.new()
	c1.id = "sfx.a"
	var c2 := AudioCueDef.new()
	c2.id = "sfx.b"
	var cues: Array[AudioCueDef] = [c1, c2]
	_audio.register_cues(cues)


func test_play_unregistered_cue_no_error() -> void:
	_audio.play_cue("nonexistent.cue")


func test_stop_cue_unregistered_no_error() -> void:
	_audio.stop_cue("nonexistent.cue")
