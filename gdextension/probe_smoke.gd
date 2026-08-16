# gdextension/probe_smoke.gd — 探针冒烟测试（本地脚本，不提交）。
# 验证：GDExtension 加载成功 + Flecs 编入 + 边界方法可调用。
# 用法：godot --headless --path . -s res://gdextension/probe_smoke.gd
extends SceneTree


func _init() -> void:
	var probe := GF_EcsProbe.new()
	print("[PROBE] Flecs version: ", probe.get_flecs_version())
	print("[PROBE] ping: ", probe.ping())
	print("[PROBE] echo_int(42): ", probe.echo_int(42))
	print("[PROBE] echo_variant: ", probe.echo_variant({"a": 1}))
	quit()
