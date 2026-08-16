// gdextension/src/gf_ecs_native_system_host.cpp
// GF_EcsNativeSystemHost — 原生系统执行环境（性能路线图 §1.7）。
// 工厂注册表 + GDScript 可见的宿主服务：
//   - attach_world(native_world)：关联 GF_EcsNativeWorld（取原始 Flecs world）
//   - register_system(name, read_keys)：按名实例化使用方 C++ 系统，
//     建多组件 query（列顺序 = read_keys 顺序）
//   - tick_all(delta)：遍历注册系统执行 tick
//   - clear_systems()：清空注册

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <unordered_map>
#include <vector>

#include "gf_ecs_native_system.h"
#include "gf_ecs_native_world.h"

using namespace godot;

namespace {

// 工厂注册表（静态初始化期填充：GF_NATIVE_SYSTEM_REGISTER 宏在 dlopen 时执行）
std::unordered_map<std::string, GF_EcsNativeSystemFactory> &factory_registry() {
	static std::unordered_map<std::string, GF_EcsNativeSystemFactory> registry;
	return registry;
}

} // namespace

bool gf_ecs_native_system_register(const char *p_name, GF_EcsNativeSystemFactory p_factory) {
	if (p_name == nullptr || p_factory == nullptr) {
		return false;
	}
	factory_registry()[p_name] = p_factory;
	return true;
}

GF_EcsNativeSystem *gf_ecs_native_system_create(const char *p_name) {
	auto &registry = factory_registry();
	auto it = registry.find(p_name);
	if (it == registry.end()) {
		return nullptr;
	}
	return it->second();
}

class GF_EcsNativeSystemHost : public RefCounted {
	GDCLASS(GF_EcsNativeSystemHost, RefCounted)

	struct Entry {
		String name;
		GF_EcsNativeSystem *system = nullptr;
		ecs_query_t *query = nullptr;
	};

	GF_EcsNativeWorld *native_world = nullptr;
	std::vector<Entry> entries;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("attach_world", "native_world"), &GF_EcsNativeSystemHost::attach_world);
		ClassDB::bind_method(D_METHOD("register_system", "name", "read_keys"), &GF_EcsNativeSystemHost::register_system);
		ClassDB::bind_method(D_METHOD("tick_all", "delta"), &GF_EcsNativeSystemHost::tick_all);
		ClassDB::bind_method(D_METHOD("clear_systems"), &GF_EcsNativeSystemHost::clear_systems);
	}

public:
	~GF_EcsNativeSystemHost() {
		clear_entries();
	}

	// GDScript：关联原生世界（必须先于 register_system 调用）
	bool attach_world(GF_EcsNativeWorld *p_native_world) {
		if (p_native_world == nullptr) {
			return false;
		}
		clear_entries();
		native_world = p_native_world;
		return true;
	}

	// GDScript：按名实例化使用方系统并建查询。
	// read_keys 决定查询列顺序（tick 内 ecs_field_w_size 的 index 对应它）。
	bool register_system(const String &p_name, const PackedInt64Array &p_read_keys) {
		if (native_world == nullptr || p_read_keys.is_empty()) {
			return false;
		}
		GF_EcsNativeSystem *system = gf_ecs_native_system_create(p_name.utf8().get_data());
		if (system == nullptr) {
			return false; // 未注册的工厂名（使用方忘了宏注册或拼错）
		}
		ecs_query_t *query = build_query(p_read_keys);
		if (query == nullptr) {
			delete system;
			return false;
		}
		entries.push_back({ p_name, system, query });
		return true;
	}

	// GDScript：每帧调用（由框架调度或使用方自行编排）
	void tick_all(double p_delta) {
		if (native_world == nullptr) {
			return;
		}
		for (const Entry &entry : entries) {
			ecs_iter_t it = ecs_query_iter(native_world->get_raw_world(), entry.query);
			while (ecs_query_next(&it)) {
				entry.system->tick(&it, p_delta);
			}
		}
	}

	void clear_systems() {
		clear_entries();
	}

private:
	ecs_query_t *build_query(const PackedInt64Array &p_read_keys) {
		ecs_query_desc_t desc = {};
		for (int64_t i = 0; i < p_read_keys.size() && i < FLECS_TERM_COUNT_MAX; i++) {
			ecs_entity_t comp = native_world->get_comp_entity(p_read_keys[i]);
			if (comp == 0) {
				return nullptr; // type_key 未注册组件（世界侧没 add 过该类型）
			}
			desc.terms[i].id = comp;
		}
		return ecs_query_init(native_world->get_raw_world(), &desc);
	}

	void clear_entries() {
		for (Entry &entry : entries) {
			if (entry.query != nullptr) {
				ecs_query_fini(entry.query);
			}
			delete entry.system;
		}
		entries.clear();
	}
};

// 由扩展入口（gf_ecs_probe.cpp）在初始化时调用。
void register_gf_ecs_native_system_host() {
	ClassDB::register_class<GF_EcsNativeSystemHost>();
}
