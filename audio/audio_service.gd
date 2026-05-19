## AudioService
## 游戏音频服务。支持 AudioCue 体系（推荐）和路径直调（向后兼容）。
##
## 使用方式：
##   [codeblock]
##   var audio := context.audio
##   audio.register_cues(GameAudioConfig.get_cues())
##   audio.play_cue("ui.click")
##   audio.play_cue("sfx.build")
##   [/codeblock]
class_name AudioService
extends ModuleLifecycle

var _runtime: AudioRuntime = null
var _resource: ResourceService = null
var _log: LogService = null

var _cue_defs: Dictionary = {}          # id -> AudioCueDef
var _cue_cooldowns: Dictionary = {}     # id -> last_play_time_ms
var _cue_active_counts: Dictionary = {} # id -> int


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_runtime: AudioRuntime, p_resource: ResourceService, p_log: LogService) -> OperationResult:
	if p_runtime == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: runtime 不能为 null", module_name)
	if p_resource == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: resource 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", module_name)
	_runtime = p_runtime
	_resource = p_resource
	_log = p_log
	return OperationResult.ok()


# ============================================================
# AudioCue 注册
# ============================================================

## 注册单个 cue 定义
func register_cue(p_def: AudioCueDef) -> void:
	_cue_defs[p_def.id] = p_def


## 批量注册 cue 定义
func register_cues(p_defs: Array[AudioCueDef]) -> void:
	for def in p_defs:
		register_cue(def)
	_log.info("Audio", "Cue 注册完成，共 %d 个" % _cue_defs.size())


# ============================================================
# AudioCue 播放
# ============================================================

## 通过 cue ID 播放。自动处理冷却和并发限制。
func play_cue(p_id: String) -> void:
	if not _cue_defs.has(p_id):
		_log.warning("Audio", "Cue 未注册: %s" % p_id)
		return

	var def: AudioCueDef = _cue_defs[p_id]

	if not _check_cooldown(def):
		return
	if not _check_max_instances(def):
		return

	var result := _resource.load_audio(def.path)
	if result.is_fail():
		_log.error("Audio", "Cue 加载失败: %s → %s" % [p_id, def.path])
		return

	_play_by_channel(def.channel, result.data)
	_cue_active_counts[p_id] = _cue_active_counts.get(p_id, 0) + 1
	_cue_cooldowns[p_id] = Time.get_ticks_msec()


## 停止指定 cue（同 channel 的所有正在播放的实例）
func stop_cue(p_id: String) -> void:
	if not _cue_defs.has(p_id):
		return
	var def: AudioCueDef = _cue_defs[p_id]
	_runtime.stop(def.channel)
	_cue_active_counts[p_id] = 0


# ============================================================
# 向后兼容：路径直调
# ============================================================

func play_bgm(p_path: String) -> void:
	var result := _resource.load_audio(p_path)
	if result.is_fail():
		_log.error("Audio", "BGM 加载失败: %s" % p_path)
		return
	_runtime.play_bgm(result.data)


func play_sfx(p_path: String) -> void:
	var result := _resource.load_audio(p_path)
	if result.is_fail():
		_log.error("Audio", "SFX 加载失败: %s" % p_path)
		return
	_runtime.play_sfx(result.data)


func play_ui_sfx(p_path: String) -> void:
	var result := _resource.load_audio(p_path)
	if result.is_fail():
		_log.error("Audio", "UI 音效加载失败: %s" % p_path)
		return
	_runtime.play_ui(result.data)


# ============================================================
# 控制
# ============================================================

func stop(p_channel: AudioRuntime.Channel) -> void:
	_runtime.stop(p_channel)


func stop_bgm() -> void:
	_runtime.stop(AudioRuntime.Channel.BGM)


func set_volume(p_channel: AudioRuntime.Channel, p_volume: float) -> void:
	_runtime.set_volume(p_channel, p_volume)


func get_volume(p_channel: AudioRuntime.Channel) -> float:
	return _runtime.get_volume(p_channel)


func mute(p_channel: AudioRuntime.Channel) -> void:
	_runtime.mute(p_channel)


func unmute(p_channel: AudioRuntime.Channel) -> void:
	_runtime.unmute(p_channel)


func is_muted(p_channel: AudioRuntime.Channel) -> bool:
	return _runtime.is_muted(p_channel)


# ============================================================
# 内部
# ============================================================

func _check_cooldown(p_def: AudioCueDef) -> bool:
	if p_def.cooldown_ms <= 0:
		return true
	var last = _cue_cooldowns.get(p_def.id, 0)
	if last == 0:
		return true
	var elapsed = Time.get_ticks_msec() - last
	return elapsed >= p_def.cooldown_ms


func _check_max_instances(p_def: AudioCueDef) -> bool:
	if p_def.max_instances <= 0:
		return true
	var count = _cue_active_counts.get(p_def.id, 0)
	return count < p_def.max_instances


func _play_by_channel(p_channel: AudioRuntime.Channel, p_stream: AudioStream) -> void:
	match p_channel:
		AudioRuntime.Channel.BGM:   _runtime.play_bgm(p_stream)
		AudioRuntime.Channel.SFX:   _runtime.play_sfx(p_stream)
		AudioRuntime.Channel.UI:    _runtime.play_ui(p_stream)
		AudioRuntime.Channel.VOICE: _runtime.play_voice(p_stream)
