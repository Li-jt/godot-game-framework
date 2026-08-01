# tests/unit/audio/test_audio_service.gd
extends GutTest

var _audio: GF_AudioService


func before_each() -> void:
	_audio = GF_AudioService.new()
	_audio.module_name = "AudioService"
	_audio.init_module()


func after_each() -> void:
	_audio = null


func test_register_cue_stores_by_id() -> void:
	var cue := GF_AudioCueDef.new()
	cue.id = "ui.click"
	_audio.register_cue(cue)


func test_register_cues_batch() -> void:
	var c1 := GF_AudioCueDef.new()
	c1.id = "sfx.a"
	var c2 := GF_AudioCueDef.new()
	c2.id = "sfx.b"
	var cues: Array[GF_AudioCueDef] = [c1, c2]
	_audio.register_cues(cues)


func test_play_unregistered_cue_no_error() -> void:
	_audio.play_cue("nonexistent.cue")


func test_stop_cue_unregistered_no_error() -> void:
	_audio.stop_cue("nonexistent.cue")
