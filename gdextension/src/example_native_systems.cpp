// gdextension/src/example_native_systems.cpp
// 示例原生系统（§1.7 开发指南的参考实现 + benchmark 验收件）。
//
// MoveNativeSystem：Position.value += Velocity.value * delta——
// 与 GDScript 等价系统（tests/benchmark 对拍）验证执行环境 ≥10x。
// 直写列不产生变更事件（§1.7 首版语义，见开发指南）。

#include <godot_cpp/variant/dictionary.hpp>

#include "gf_ecs_native_system.h"

using namespace godot;

// type_key 由 GDScript 侧 registry 分配；benchmark 场景下 Position=1 Velocity=2
constexpr int64_t KEY_POSITION = 1;
constexpr int64_t KEY_VELOCITY = 2;

class MoveNativeSystem : public GF_EcsNativeSystem {
public:
	void tick(ecs_iter_t *it, double delta) override {
		Variant **pos_col = static_cast<Variant **>(ecs_field_w_size(it, sizeof(Variant *), 0));
		Variant **vel_col = static_cast<Variant **>(ecs_field_w_size(it, sizeof(Variant *), 1));
		for (int i = 0; i < it->count; i++) {
			Dictionary pos = (*pos_col[i]);
			Dictionary vel = (*vel_col[i]);
			pos["x"] = double(pos["x"]) + double(vel["vx"]) * delta;
			pos["y"] = double(pos["y"]) + double(vel["vy"]) * delta;
		}
	}
};

GF_NATIVE_SYSTEM_REGISTER(MoveNativeSystem, []() -> GF_EcsNativeSystem * { return new MoveNativeSystem(); })
