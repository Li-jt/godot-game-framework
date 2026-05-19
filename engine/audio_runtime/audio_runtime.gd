## AudioRuntime
## 音频运行时宿主。管理音频播放节点和通道。
## 后续由 AudioService（T3-5）在此基础上提供高层接口（资源加载、淡入淡出等）。
##
## 通道设计：
##   MASTER — 总控
##   BGM    — 背景音乐（循环）
##   SFX    — 游戏音效（一次性，支持同时播放多个）
##   UI     — UI 交互音效
##   VOICE  — 语音/对话
##
## 使用方式：
##   [codeblock]
##   var audio: AudioRuntime = injected_audio_runtime
##   audio.play_bgm(some_stream)
##   audio.play_sfx(click_stream)
##   audio.set_volume(AudioRuntime.Channel.SFX, 0.8)
##   [/codeblock]
class_name AudioRuntime
extends Node

enum Channel {
	MASTER,
	BGM,
	SFX,
	UI,
	VOICE
}

const MAX_SFX_PLAYERS := 8  # SFX 池大小，支持同时播放多个音效

var _players: Dictionary = {}       # Channel -> AudioStreamPlayer（BGM/UI/VOICE）
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _volumes: Dictionary = {}       # Channel -> float
var _muted: Dictionary = {}         # Channel -> bool


func _ready() -> void:
	_setup()


## 音频播放器是否已就绪（供 verify_required 检查）
func is_runtime_ready() -> bool:
	return _players.size() > 0 and _sfx_pool.size() > 0


# ============================================================
# 播放
# ============================================================

## 播放 BGM（默认循环），切换 BGM 时自动停止上一首
func play_bgm(p_stream: AudioStream) -> void:
	var player := _get_player(Channel.BGM)
	player.stream = p_stream
	player.play()


## 播放音效（一次性，支持同时多个）
func play_sfx(p_stream: AudioStream) -> void:
	var player := _next_sfx_player()
	player.stream = p_stream
	player.play()


## 播放 UI 音效
func play_ui(p_stream: AudioStream) -> void:
	var player := _get_player(Channel.UI)
	player.stream = p_stream
	player.play()


## 播放语音
func play_voice(p_stream: AudioStream) -> void:
	var player := _get_player(Channel.VOICE)
	player.stream = p_stream
	player.play()


# ============================================================
# 控制
# ============================================================

## 停止指定通道
func stop(p_channel: Channel) -> void:
	if p_channel == Channel.SFX:
		for p in _sfx_pool:
			p.stop()
	else:
		_get_player(p_channel).stop()


## 设置通道音量（0.0 ~ 1.0）
func set_volume(p_channel: Channel, p_volume: float) -> void:
	var v := clampf(p_volume, 0.0, 1.0)
	_volumes[p_channel] = v
	_apply_db(p_channel, v)


## 获取通道音量
func get_volume(p_channel: Channel) -> float:
	return _volumes.get(p_channel, 1.0)


## 静音
func mute(p_channel: Channel) -> void:
	_muted[p_channel] = true
	_apply_mute(p_channel)


## 取消静音
func unmute(p_channel: Channel) -> void:
	_muted[p_channel] = false
	_apply_mute(p_channel)


## 是否静音
func is_muted(p_channel: Channel) -> bool:
	return _muted.get(p_channel, false)


# ============================================================
# 内部
# ============================================================

func _setup() -> void:
	for ch in [Channel.BGM, Channel.UI, Channel.VOICE]:
		_volumes[ch] = 1.0
		_muted[ch] = false
		_create_player(ch)
	_volumes[Channel.SFX] = 1.0
	_muted[Channel.SFX] = false
	for i in MAX_SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


func _get_player(p_channel: Channel) -> AudioStreamPlayer:
	return _players[p_channel] as AudioStreamPlayer


func _next_sfx_player() -> AudioStreamPlayer:
	var p := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	if p.playing:
		p.stop()
	return p


func _create_player(p_channel: Channel) -> void:
	var p := AudioStreamPlayer.new()
	p.name = _channel_name(p_channel)
	p.bus = _bus_name(p_channel)
	add_child(p)
	_players[p_channel] = p


func _apply_db(p_channel: Channel, p_volume: float) -> void:
	var db := linear_to_db(p_volume) if p_volume > 0.0 else -80.0
	if p_channel == Channel.SFX:
		for p in _sfx_pool:
			p.volume_db = db
	else:
		_get_player(p_channel).volume_db = db


func _apply_mute(p_channel: Channel) -> void:
	var muted = _muted.get(p_channel, false)
	var db := -80.0 if muted else linear_to_db(_volumes.get(p_channel, 1.0))
	if p_channel == Channel.SFX:
		for p in _sfx_pool:
			p.volume_db = db
	else:
		_get_player(p_channel).volume_db = db


func _channel_name(p_channel: Channel) -> String:
	match p_channel:
		Channel.BGM:   return "BGM"
		Channel.SFX:   return "SFX"
		Channel.UI:    return "UI"
		Channel.VOICE: return "Voice"
		_: return "Audio"


func _bus_name(p_channel: Channel) -> String:
	match p_channel:
		Channel.MASTER: return "Master"
		Channel.BGM:    return "BGM"
		Channel.SFX:    return "SFX"
		Channel.UI:     return "UI"
		Channel.VOICE:  return "Voice"
		_: return "Master"
