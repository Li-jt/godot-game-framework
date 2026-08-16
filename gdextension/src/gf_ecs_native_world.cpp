// gdextension/src/gf_ecs_native_world.cpp
// GF_EcsNativeWorld — Flecs 后端的最小集成探针（性能路线图 §1.8 数据点 2/3）。
//
// 探针形态的简化（与 §1.6 最终形态的差异，报告必须诚实声明）：
// - 组件列存 Variant* 堆指针（值型列存储的 Variant 生命周期钩子是 §1.6 设计工作）；
// - 实体 id 直接透传 Flecs 的 index+generation id（不实现「单调不复用」适配）；
// - 组件类型键是 int64（GDScript 侧负责 GDScript 类型 → 键的映射）；
// - 事件收集是 C++ 侧 buffer + flush_events() 打包返回（与 GF_EcsChangeLog
//   「单帧生命周期 + clear」同构，等价性对拍见数据点 3）。

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <flecs.h>

#include <vector>

using namespace godot;

namespace {

// 事件记录（对齐 GF_EcsChangeLog 的三类事件 + 实体增删）
enum class ProbeEventKind : int64_t {
	ENTITY_ADDED = 0,
	ENTITY_REMOVED = 1,
	COMPONENT_ADDED = 2,
	COMPONENT_CHANGED = 3,
	COMPONENT_REMOVED = 4,
};

struct EventRecord {
	uint64_t entity;
	int64_t type_key;
	ProbeEventKind kind;
};

// 每实体「存活标记」tag：spawn 时加上，借 Flecs 的 OnAdd/OnRemove 事件
// 承载实体增删记录（Flecs 裸实体创建本身没有组件事件）。
const char *ALIVE_TAG_NAME = "GfProbeAlive";

// 组件列元素是堆上 Variant 的指针；组件被移除/实体销毁时由 dtor 钩子释放。
// v4 的 xtor 钩子签名：(ptr, count, type_info)，ptr 指向组件数组首元素。
void comp_dtor(void *p_ptr, int32_t p_count, const ecs_type_info_t *p_type_info) {
	Variant **col = static_cast<Variant **>(p_ptr);
	for (int32_t i = 0; i < p_count; i++) {
		if (col[i] != nullptr) {
			memdelete(col[i]);
		}
	}
}

// 组件名 → type_key（"Comp_<key>" 命名，事件回调时反解）
String comp_name(int64_t p_type_key) {
	return String("Comp_") + String::num_int64(p_type_key);
}

} // namespace

class GF_EcsNativeWorld : public RefCounted {
	GDCLASS(GF_EcsNativeWorld, RefCounted)

	ecs_world_t *world = nullptr;
	ecs_entity_t alive_tag = 0;
	int64_t alive_count = 0; // 存活实体计数（O(1)，v4 无 EcsAlive 全遍历捷径）
	int64_t version = 0; // mutation 计数（GDScript 门面同步维护，原生侧自洽）
	HashMap<int64_t, ecs_entity_t> comp_ids; // type_key -> flecs component entity
	HashMap<int64_t, ecs_query_t *> queries; // type_key -> 缓存的查询（benchmark 公平性）
	std::vector<EventRecord> events; // 事件收集 buffer（flush_events 清空）

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("spawn"), &GF_EcsNativeWorld::spawn);
		ClassDB::bind_method(D_METHOD("despawn", "entity"), &GF_EcsNativeWorld::despawn);
		ClassDB::bind_method(D_METHOD("has_entity", "entity"), &GF_EcsNativeWorld::has_entity);
		ClassDB::bind_method(D_METHOD("entity_count"), &GF_EcsNativeWorld::entity_count);

		ClassDB::bind_method(D_METHOD("add_component", "entity", "type_key", "data"), &GF_EcsNativeWorld::add_component);
		ClassDB::bind_method(D_METHOD("set_component", "entity", "type_key", "data"), &GF_EcsNativeWorld::set_component);
		ClassDB::bind_method(D_METHOD("get_component", "entity", "type_key"), &GF_EcsNativeWorld::get_component);
		ClassDB::bind_method(D_METHOD("remove_component", "entity", "type_key"), &GF_EcsNativeWorld::remove_component);
		ClassDB::bind_method(D_METHOD("has_component", "entity", "type_key"), &GF_EcsNativeWorld::has_component);

		ClassDB::bind_method(D_METHOD("get_version"), &GF_EcsNativeWorld::get_version);
		ClassDB::bind_method(D_METHOD("all_entities"), &GF_EcsNativeWorld::all_entities);
		ClassDB::bind_method(D_METHOD("reset"), &GF_EcsNativeWorld::reset);

		// 原生查询游标：C++ 侧循环，逐实体回调 GDScript（真实使用形态）
		ClassDB::bind_method(D_METHOD("for_each", "type_key", "callback"), &GF_EcsNativeWorld::for_each);
		// 纯 C++ 侧求和（理论天花板档，数据点 2 用）
		ClassDB::bind_method(D_METHOD("sum_value_field", "type_key"), &GF_EcsNativeWorld::sum_value_field);

		// 变更事件收集（数据点 3 用）
		ClassDB::bind_method(D_METHOD("flush_events"), &GF_EcsNativeWorld::flush_events);
	}

public:
	GF_EcsNativeWorld() {
		world = ecs_init();

		// 存活标记 tag：spawn 加、despawn 自然移除，OnAdd/OnRemove 承载实体增删事件
		ecs_entity_desc_t alive_desc = {};
		alive_desc.name = ALIVE_TAG_NAME;
		alive_tag = ecs_entity_init(world, &alive_desc);

		ecs_observer_desc_t alive_obs = {};
		alive_obs.query.terms[0].id = alive_tag;
		alive_obs.events[0] = EcsOnAdd;
		alive_obs.events[1] = EcsOnRemove;
		alive_obs.callback = on_alive_event;
		alive_obs.ctx = this;
		ecs_observer_init(world, &alive_obs);
	}

	~GF_EcsNativeWorld() {
		if (world == nullptr) {
			return;
		}
		for (HashMap<int64_t, ecs_query_t *>::Iterator it = queries.begin(); it != queries.end(); ++it) {
			ecs_query_fini(it->value);
		}
		queries.clear();
		ecs_fini(world);
		world = nullptr;
	}

	// ============================================================
	// 实体生命周期
	// ============================================================

	int64_t spawn() {
		ecs_entity_t e = ecs_new(world);
		ecs_add_id(world, e, alive_tag);
		alive_count++;
		version++;
		return static_cast<int64_t>(e);
	}

	bool despawn(int64_t p_entity) {
		ecs_entity_t e = static_cast<uint64_t>(p_entity);
		if (!ecs_is_alive(world, e)) {
			return false;
		}
		ecs_delete(world, e);
		alive_count--;
		version++;
		return true;
	}

	bool has_entity(int64_t p_entity) {
		return ecs_is_alive(world, static_cast<uint64_t>(p_entity));
	}

	int64_t entity_count() {
		return alive_count;
	}

	// ============================================================
	// 组件操作
	// ============================================================

	bool add_component(int64_t p_entity, int64_t p_type_key, const Variant &p_data) {
		ecs_entity_t e = static_cast<uint64_t>(p_entity);
		if (!ecs_is_alive(world, e)) {
			return false;
		}
		ecs_entity_t comp = get_or_create_comp(p_type_key);
		if (ecs_has_id(world, e, comp)) {
			return false; // 对齐 GF_EcsWorld：已有组件时 add 失败
		}
		// add + 直接写列：只产生 OnAdd（对齐 GF_EcsChangeLog 的 ADDED 单条语义）
		ecs_add_id(world, e, comp);
		Variant **slot = static_cast<Variant **>(ecs_get_mut_id(world, e, comp));
		*slot = memnew(Variant(p_data));
		version++;
		return true;
	}

	bool set_component(int64_t p_entity, int64_t p_type_key, const Variant &p_data) {
		ecs_entity_t e = static_cast<uint64_t>(p_entity);
		if (!ecs_is_alive(world, e)) {
			return false;
		}
		ecs_entity_t comp = get_or_create_comp(p_type_key);
		// 换值 + 触发 OnSet。首次 set（组件不存在）会先产生 OnAdd——
		// 与 GF_EcsChangeLog 的「set 只记 CHANGED」存在差异，由 GDScript
		// 门面在事件泵过滤（§1.8 适配点 1）。返回值语义 = 是否成功。
		ecs_add_id(world, e, comp);
		Variant **slot = static_cast<Variant **>(ecs_get_mut_id(world, e, comp));
		if (*slot != nullptr) {
			memdelete(*slot); // 列直接操作不走 dtor 钩子，旧值手动释放
		}
		*slot = memnew(Variant(p_data));
		ecs_modified_id(world, e, comp);
		version++;
		return true;
	}

	Variant get_component(int64_t p_entity, int64_t p_type_key) {
		ecs_entity_t e = static_cast<uint64_t>(p_entity);
		if (!ecs_is_alive(world, e)) {
			return Variant();
		}
		ecs_entity_t *comp = comp_ids.getptr(p_type_key);
		if (comp == nullptr || !ecs_has_id(world, e, *comp)) {
			return Variant();
		}
		// 列里存的是 Variant*（指针值），get_id 返回指向该指针的指针
		const Variant *const *slot = static_cast<const Variant *const *>(ecs_get_id(world, e, *comp));
		return Variant(**slot);
	}

	bool remove_component(int64_t p_entity, int64_t p_type_key) {
		ecs_entity_t e = static_cast<uint64_t>(p_entity);
		ecs_entity_t *comp = comp_ids.getptr(p_type_key);
		if (comp == nullptr || !ecs_is_alive(world, e) || !ecs_has_id(world, e, *comp)) {
			return false;
		}
		ecs_remove_id(world, e, *comp);
		version++;
		return true;
	}

	int64_t get_version() {
		return version;
	}

	// 所有存活实体（Flecs 原生 id；GDScript 门面负责映射为框架 id）
	PackedInt64Array all_entities() {
		PackedInt64Array out;
		ecs_query_t *q = get_or_create_alive_query();
		ecs_iter_t it = ecs_query_iter(world, q);
		while (ecs_query_next(&it)) {
			for (int i = 0; i < it.count; i++) {
				out.append(static_cast<int64_t>(it.entities[i]));
			}
		}
		return out;
	}

	// 删除全部实体并清空事件与版本。
	// 组件类型注册保留（Flecs entity 按名唯一，type_key 重新映射到同一 entity，
	// observer 不重复挂载）；GDScript 侧 registry 重建后 type_id 与原生 key 重新对齐。
	void reset() {
		ecs_delete_with(world, alive_tag);
		events.clear();
		alive_count = 0;
		version = 0;
	}

	bool has_component(int64_t p_entity, int64_t p_type_key) {
		ecs_entity_t e = static_cast<uint64_t>(p_entity);
		ecs_entity_t *comp = comp_ids.getptr(p_type_key);
		if (comp == nullptr || !ecs_is_alive(world, e)) {
			return false;
		}
		return ecs_has_id(world, e, *comp);
	}

	// ============================================================
	// 原生查询游标（数据点 2）
	// ============================================================

	void for_each(int64_t p_type_key, const Callable &p_callback) {
		ecs_query_t *q = get_or_create_query(p_type_key);
		if (q == nullptr) {
			return;
		}
		ecs_iter_t it = ecs_query_iter(world, q);
		while (ecs_query_next(&it)) {
			for (int i = 0; i < it.count; i++) {
				p_callback.call(static_cast<int64_t>(it.entities[i]));
			}
		}
	}

	double sum_value_field(int64_t p_type_key) {
		ecs_query_t *q = get_or_create_query(p_type_key);
		if (q == nullptr) {
			return 0.0;
		}
		double sum = 0.0;
		ecs_iter_t it = ecs_query_iter(world, q);
		while (ecs_query_next(&it)) {
			Variant **col = static_cast<Variant **>(ecs_field_w_size(&it, sizeof(Variant *), 1));
			for (int i = 0; i < it.count; i++) {
				Dictionary d = (*col[i]);
				sum += double(d["value"]);
			}
		}
		return sum;
	}

	// ============================================================
	// 变更事件收集（数据点 3）
	// ============================================================

	Array flush_events() {
		Array out;
		for (const EventRecord &rec : events) {
			Dictionary d;
			d["entity"] = static_cast<int64_t>(rec.entity);
			d["type_key"] = rec.type_key;
			d["kind"] = static_cast<int64_t>(rec.kind);
			out.append(d);
		}
		events.clear();
		return out;
	}

private:
	ecs_entity_t get_or_create_comp(int64_t p_type_key) {
		ecs_entity_t *found = comp_ids.getptr(p_type_key);
		if (found != nullptr) {
			return *found;
		}
		// 组件列存 Variant* 指针值，dtor 钩子负责释放堆 Variant
		CharString name_utf8 = comp_name(p_type_key).utf8();
		ecs_entity_desc_t ent_desc = {};
		ent_desc.name = name_utf8.get_data();
		ecs_component_desc_t comp_desc = {};
		comp_desc.entity = ecs_entity_init(world, &ent_desc);
		comp_desc.type.size = ECS_SIZEOF(Variant *);
		comp_desc.type.alignment = ECS_ALIGNOF(Variant *);
		comp_desc.type.hooks.dtor = comp_dtor;
		ecs_entity_t comp = ecs_component_init(world, &comp_desc);

		ecs_observer_desc_t obs = {};
		obs.query.terms[0].id = comp;
		obs.events[0] = EcsOnAdd;
		obs.events[1] = EcsOnSet;
		obs.events[2] = EcsOnRemove;
		obs.callback = on_comp_event;
		obs.ctx = this;
		ecs_observer_init(world, &obs);

		comp_ids[p_type_key] = comp;
		return comp;
	}

	ecs_query_t *get_or_create_query(int64_t p_type_key) {
		ecs_query_t **found = queries.getptr(p_type_key);
		if (found != nullptr) {
			return *found;
		}
		ecs_entity_t *comp = comp_ids.getptr(p_type_key);
		if (comp == nullptr) {
			return nullptr;
		}
		ecs_query_desc_t q_desc = {};
		q_desc.terms[0].id = *comp;
		ecs_query_t *q = ecs_query_init(world, &q_desc);
		queries[p_type_key] = q;
		return q;
	}

	// 全量存活实体查询（每个实体都有 alive tag），懒创建 + 缓存
	ecs_query_t *get_or_create_alive_query() {
		ecs_query_t **found = queries.getptr(0);
		if (found != nullptr) {
			return *found;
		}
		ecs_query_desc_t q_desc = {};
		q_desc.terms[0].id = alive_tag;
		ecs_query_t *q = ecs_query_init(world, &q_desc);
		queries[0] = q;
		return q;
	}

	static void on_alive_event(ecs_iter_t *it) {
		GF_EcsNativeWorld *self = static_cast<GF_EcsNativeWorld *>(it->ctx);
		ProbeEventKind kind = (it->event == EcsOnAdd) ? ProbeEventKind::ENTITY_ADDED : ProbeEventKind::ENTITY_REMOVED;
		for (int i = 0; i < it->count; i++) {
			self->events.push_back({ it->entities[i], 0, kind });
		}
	}

	static void on_comp_event(ecs_iter_t *it) {
		GF_EcsNativeWorld *self = static_cast<GF_EcsNativeWorld *>(it->ctx);
		ProbeEventKind kind;
		if (it->event == EcsOnAdd) {
			kind = ProbeEventKind::COMPONENT_ADDED;
		} else if (it->event == EcsOnSet) {
			kind = ProbeEventKind::COMPONENT_CHANGED;
		} else {
			kind = ProbeEventKind::COMPONENT_REMOVED;
		}
		int64_t type_key = self->type_key_of(it->event_id);
		for (int i = 0; i < it->count; i++) {
			self->events.push_back({ it->entities[i], type_key, kind });
		}
	}

	int64_t type_key_of(ecs_entity_t p_component) {
		const char *name = ecs_get_name(world, p_component);
		if (name == nullptr) {
			return -1;
		}
		// "Comp_<key>" → key
		return String(name + 5).to_int();
	}
};

// 由扩展入口（gf_ecs_probe.cpp）在初始化时调用。
void register_gf_ecs_native_world() {
	ClassDB::register_class<GF_EcsNativeWorld>();
}
