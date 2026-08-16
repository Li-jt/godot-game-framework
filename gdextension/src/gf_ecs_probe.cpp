// gdextension/src/gf_ecs_probe.cpp
// GDExtension 探针（性能路线图 §1.8）：验证编译链 + 边界调用开销测量目标。
// 最小集成验证通过后，此文件演进为 GF_EcsNativeWorld 门面。

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <flecs.h>

using namespace godot;

// 定义在 gf_ecs_native_world.cpp
void register_gf_ecs_native_world();

class GF_EcsProbe : public RefCounted {
	GDCLASS(GF_EcsProbe, RefCounted)

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("get_flecs_version"), &GF_EcsProbe::get_flecs_version);
		// 边界调用开销三档测量目标（§1.8 数据点 1）：
		// 无参 no-op / 单 int 参数 / Variant 参数
		ClassDB::bind_method(D_METHOD("ping"), &GF_EcsProbe::ping);
		ClassDB::bind_method(D_METHOD("echo_int", "value"), &GF_EcsProbe::echo_int);
		ClassDB::bind_method(D_METHOD("echo_variant", "value"), &GF_EcsProbe::echo_variant);
	}

public:
	String get_flecs_version() const {
		return String::num_uint64(FLECS_VERSION_MAJOR) + "." +
				String::num_uint64(FLECS_VERSION_MINOR) + "." +
				String::num_uint64(FLECS_VERSION_PATCH);
	}

	bool ping() const {
		return true;
	}

	int64_t echo_int(int64_t p_value) const {
		return p_value;
	}

	Variant echo_variant(const Variant &p_value) const {
		return p_value;
	}
};

void initialize_gf_ecs_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<GF_EcsProbe>();
	register_gf_ecs_native_world();
}

void uninitialize_gf_ecs_native(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// 初始化函数，.gdextension 的 entry_symbol 指向这里
GDExtensionBool GDE_EXPORT gf_ecs_native_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_gf_ecs_native);
	init_obj.register_terminator(uninitialize_gf_ecs_native);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
