## GF_AudioService
## 游戏音频服务。AudioCue 体系 + AudioBus 总线 + 淡入淡出。
##
## 使用方式：
##   [codeblock]
##   audio.register_cues(GameAudioConfig.get_cues())
##   audio.play_cue("ui.click")
##
##   # Bus 管理
##   audio.register_bus("Ambient", GF_AudioRuntime.Channel.BGM)
##   audio.set_bus_volume_db("BGM", -6.0)
##   audio.fade_bus_to("BGM", -20.0, 2.0)
##   audio.mute_bus("SFX")
##   audio.stop_bus("BGM")
##
##   # 在主循环中驱动淡入淡出
##   audio.tick(delta)
##   [/codeblock]
class_name GF_AudioService
extends GF_ModuleLifecycle

var _runtime: GF_AudioRuntime = null
var _resource: GF_ResourceService = null
var _log: GF_LogService = null

var _cue_defs: Dictionary = {}
var _cue_cooldowns: Dictionary = {}
var _cue_active_counts: Dictionary = {}
var _buses: Dictionary = {}


func _on_init() -> GF_OperationResult:
	_setup_default_buses()
	return GF_OperationResult.ok()


func configure(p_runtime: GF_AudioRuntime, p_resource: GF_ResourceService, p_log: GF_LogService) -> GF_OperationResult:
	if p_runtime == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: runtime 不能为 null", module_name)
	if p_resource == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: resource 不能为 null", module_name)
	if p_log == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", module_name)
	_runtime = p_runtime
	_resource = p_resource
	_log = p_log
	return GF_OperationResult.ok()


# ============================================================
# AudioCue
# ============================================================

func register_cue(p_def: GF_AudioCueDef) -> void:
	_cue_defs[p_def.id] = p_def


func register_cues(p_defs: Array[GF_AudioCueDef]) -> void:
	for def in p_defs:
		register_cue(def)
	if _log != null:
		_log.info("Audio", "Cue 注册完成，共 %d 个" % _cue_defs.size())


func play_cue(p_id: String) -> void:
	if not _cue_defs.has(p_id):
		if _log != null:
			_log.warning("Audio", "Cue 未注册: %s" % p_id)
		return
	var def: GF_AudioCueDef = _cue_defs[p_id]
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


func stop_cue(p_id: String) -> void:
	if not _cue_defs.has(p_id):
		return
	var def: GF_AudioCueDef = _cue_defs[p_id]
	if _runtime != null:
		_runtime.stop(def.channel)
	_cue_active_counts[p_id] = 0


# ============================================================
# Bus 管理
# ============================================================

func register_bus(p_name: String, p_channel: int) -> GF_OperationResult:
	if _buses.has(p_name):
		return GF_OperationResult.fail(GF_OperationResult.ERR_CONFLICT, "Bus 已存在: %s" % p_name, module_name)
	var bus := GF_AudioBus.new()
	bus.bus_name = p_name
	bus.channel = p_channel
	bus.current_volume_db = 0.0
	bus.target_volume_db = 0.0
	_buses[p_name] = bus
	return GF_OperationResult.ok()


func get_bus(p_name: String) -> Variant:
	return _buses.get(p_name, null)


func get_bus_names() -> Array[String]:
	var names: Array[String] = []
	for name in _buses.keys():
		names.append(name)
	return names


func has_bus(p_name: String) -> bool:
	return _buses.has(p_name)


# ============================================================
# Bus 音量
# ============================================================

func set_bus_volume_db(p_bus_name: String, p_db: float) -> void:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		_log.warning("Audio", "Bus 不存在: %s" % p_bus_name)
		return
	bus.target_volume_db = p_db
	bus.current_volume_db = p_db
	bus.fade_duration = 0.0
	bus.fade_elapsed = 0.0
	_apply_bus_volume(bus)


func get_bus_volume_db(p_bus_name: String) -> float:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		return 0.0
	return bus.current_volume_db


# ============================================================
# Bus 淡入淡出
# ============================================================

func fade_bus_to(p_bus_name: String, p_target_db: float, p_duration: float) -> void:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		_log.warning("Audio", "Bus 不存在: %s" % p_bus_name)
		return
	if p_duration <= 0.0:
		set_bus_volume_db(p_bus_name, p_target_db)
		return
	bus.fade_start_db = bus.current_volume_db
	bus.target_volume_db = p_target_db
	bus.fade_duration = maxf(p_duration, 0.001)
	bus.fade_elapsed = 0.0


func cancel_fade(p_bus_name: String) -> void:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		return
	bus.target_volume_db = bus.current_volume_db
	bus.fade_duration = 0.0
	bus.fade_elapsed = 0.0


func is_bus_fading(p_bus_name: String) -> bool:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		return false
	return bus.is_fading()


# ============================================================
# Bus 静音
# ============================================================

func mute_bus(p_bus_name: String) -> void:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		_log.warning("Audio", "Bus 不存在: %s" % p_bus_name)
		return
	bus.muted = true
	_apply_bus_volume(bus)


func unmute_bus(p_bus_name: String) -> void:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		_log.warning("Audio", "Bus 不存在: %s" % p_bus_name)
		return
	bus.muted = false
	_apply_bus_volume(bus)


func is_bus_muted(p_bus_name: String) -> bool:
	var bus = _buses.get(p_bus_name, null)
	return bus.muted if bus else false


# ============================================================
# Bus 播放控制
# ============================================================

func stop_bus(p_bus_name: String) -> void:
	var bus = _buses.get(p_bus_name, null)
	if bus == null:
		if _log != null:
			_log.warning("Audio", "Bus 不存在: %s" % p_bus_name)
		return
	if _runtime != null:
		_runtime.stop(bus.channel)


# ============================================================
# tick — 驱动淡入淡出
# ============================================================

func tick(p_delta: float) -> void:
	for key in _buses.keys():
		var bus = _buses[key]
		if bus.fade_duration <= 0.0:
			continue
		bus.fade_elapsed += p_delta
		var t: float = clampf(bus.fade_elapsed / bus.fade_duration, 0.0, 1.0)
		bus.current_volume_db = lerpf(bus.fade_start_db, bus.target_volume_db, t)
		_apply_bus_volume(bus)
		if bus.fade_elapsed >= bus.fade_duration:
			bus.fade_duration = 0.0


# ============================================================
# 内部
# ============================================================

func _setup_default_buses() -> void:
	_register_bus_internal("Master", GF_AudioRuntime.Channel.MASTER)
	_register_bus_internal("BGM", GF_AudioRuntime.Channel.BGM)
	_register_bus_internal("SFX", GF_AudioRuntime.Channel.SFX)
	_register_bus_internal("UI", GF_AudioRuntime.Channel.UI)
	_register_bus_internal("Voice", GF_AudioRuntime.Channel.VOICE)


func _register_bus_internal(p_name: String, p_channel: int) -> void:
	var bus := GF_AudioBus.new()
	bus.bus_name = p_name
	bus.channel = p_channel
	bus.current_volume_db = 0.0
	bus.target_volume_db = 0.0
	_buses[p_name] = bus


func _apply_bus_volume(p_bus: Variant) -> void:
	if _runtime == null:
		return
	var db: float = p_bus.current_volume_db
	if p_bus.muted:
		db = -80.0
	_runtime.set_volume_db(p_bus.channel, db)


func _check_cooldown(p_def: GF_AudioCueDef) -> bool:
	if p_def.cooldown_ms <= 0:
		return true
	var last = _cue_cooldowns.get(p_def.id, 0)
	if last == 0:
		return true
	var elapsed = Time.get_ticks_msec() - last
	return elapsed >= p_def.cooldown_ms


func _check_max_instances(p_def: GF_AudioCueDef) -> bool:
	if p_def.max_instances <= 0:
		return true
	var count = _cue_active_counts.get(p_def.id, 0)
	return count < p_def.max_instances


func _play_by_channel(p_channel: GF_AudioRuntime.Channel, p_stream: AudioStream) -> void:
	match p_channel:
		GF_AudioRuntime.Channel.BGM:   _runtime.play_bgm(p_stream)
		GF_AudioRuntime.Channel.SFX:   _runtime.play_sfx(p_stream)
		GF_AudioRuntime.Channel.UI:    _runtime.play_ui(p_stream)
		GF_AudioRuntime.Channel.VOICE: _runtime.play_voice(p_stream)
