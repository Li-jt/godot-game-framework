// gdextension/src/gf_ecs_native_world.h
// GF_EcsNativeWorld 类声明（实现见 gf_ecs_native_world.cpp）。
// 供同扩展内的其他 C++ 单元（如原生系统宿主）访问 raw world / 组件实体。

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <flecs.h>

#include <vector>

using namespace godot;

// 事件记录（对齐 GF_EcsChangeLog 的三类事件 + 实体增删）
enum class GF_EcsProbeEventKind : int64_t {
	ENTITY_ADDED = 0,
	ENTITY_REMOVED = 1,
	COMPONENT_ADDED = 2,
	COMPONENT_CHANGED = 3,
	COMPONENT_REMOVED = 4,
};

struct GF_EcsEventRecord {
	uint64_t entity;
	int64_t type_key;
	GF_EcsProbeEventKind kind;
};

class GF_EcsNativeWorld : public RefCounted {
	GDCLASS(GF_EcsNativeWorld, RefCounted)

	ecs_world_t *world = nullptr;
	ecs_entity_t alive_tag = 0;
	int64_t alive_count = 0; // 存活实体计数（O(1)，v4 无 EcsAlive 全遍历捷径）
	int64_t version = 0; // mutation 计数（GDScript 门面同步维护，原生侧自洽）
	HashMap<int64_t, ecs_entity_t> comp_ids; // type_key -> flecs component entity
	HashMap<int64_t, ecs_query_t *> queries; // type_key -> 缓存的查询（benchmark 公平性）
	std::vector<GF_EcsEventRecord> events; // 事件收集 buffer（flush_events 清空）

protected:
	static void _bind_methods();

public:
	GF_EcsNativeWorld();
	~GF_EcsNativeWorld();

	// ============================================================
	// 实体生命周期
	// ============================================================

	int64_t spawn();
	bool despawn(int64_t p_entity);
	bool has_entity(int64_t p_entity);
	int64_t entity_count();

	// ============================================================
	// 组件操作
	// ============================================================

	bool add_component(int64_t p_entity, int64_t p_type_key, const Variant &p_data);
	bool set_component(int64_t p_entity, int64_t p_type_key, const Variant &p_data);
	Variant get_component(int64_t p_entity, int64_t p_type_key);
	bool remove_component(int64_t p_entity, int64_t p_type_key);
	bool has_component(int64_t p_entity, int64_t p_type_key);

	int64_t get_version();
	PackedInt64Array all_entities();
	void reset();

	// ============================================================
	// 原生查询游标（数据点 2 / 原生系统宿主）
	// ============================================================

	void for_each(int64_t p_type_key, const Callable &p_callback);
	double sum_value_field(int64_t p_type_key);

	Array flush_events();

	// ============================================================
	// 仅 C++ 层访问（不绑定 GDScript）：原生系统宿主等内部单元用
	// ============================================================

	ecs_world_t *get_raw_world() const { return world; }

	// type_key -> Flecs 组件实体（未注册时返回 0）
	ecs_entity_t get_comp_entity(int64_t p_type_key) const {
		const ecs_entity_t *found = comp_ids.getptr(p_type_key);
		return found != nullptr ? *found : 0;
	}

private:
	ecs_entity_t get_or_create_comp(int64_t p_type_key);
	ecs_query_t *get_or_create_query(int64_t p_type_key);
	ecs_query_t *get_or_create_alive_query();
	int64_t type_key_of(ecs_entity_t p_component);

	static void on_alive_event(ecs_iter_t *it);
	static void on_comp_event(ecs_iter_t *it);
};
