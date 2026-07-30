## GF_AudioBus — 音频总线。
##
## 每个 Bus 对应一个 GF_AudioRuntime.Channel，拥有独立的音量（dB）、静音和淡入淡出状态。
## GF_AudioService.tick() 驱动淡入淡出插值。
class_name GF_AudioBus
extends RefCounted

## 总线名称（如 "Master"、"BGM"、"SFX"、"Voice"）。
var bus_name: String = ""

## 映射到 GF_AudioRuntime.Channel（存储为 int，用 GF_AudioRuntime.Channel 常量比较）。
var channel: int = 0  # GF_AudioRuntime.Channel.MASTER

## 当前实际音量（dB）。由 tick() 在淡入淡出期间更新。
var current_volume_db: float = 0.0

## 目标音量（dB）。
var target_volume_db: float = 0.0

## 是否静音。
var muted: bool = false

## 淡入淡出起始音量（dB）。
var fade_start_db: float = 0.0

## 淡入淡出总时长（秒）。0 表示无进行中的淡入淡出。
var fade_duration: float = 0.0

## 淡入淡出已流逝时间（秒）。
var fade_elapsed: float = 0.0


## 淡入淡出是否正在进行中。
func is_fading() -> bool:
	return fade_duration > 0.0 and fade_elapsed < fade_duration


## 淡入淡出进度（0.0 ~ 1.0）。
func fade_progress() -> float:
	if fade_duration <= 0.0:
		return 1.0
	return clampf(fade_elapsed / fade_duration, 0.0, 1.0)
