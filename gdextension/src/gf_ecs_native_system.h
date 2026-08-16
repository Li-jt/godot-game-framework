// gdextension/src/gf_ecs_native_system.h
// 原生系统执行环境（性能路线图 §1.7）——使用方系统基类与注册机制。
//
// 使用方系统是**编译进本扩展**的 C++ 子类：
// 1. 继承 GF_EcsNativeSystem，实现 tick()（热循环整体在 C++ 侧）；
// 2. 用 GF_NATIVE_SYSTEM_REGISTER 宏注册工厂（dylib 加载时自动执行）；
// 3. GDScript 侧用 GF_EcsNativeSystemHost.register_system("名字", read_keys)
//    按名实例化并声明读取的组件列。
//
// 组件列形态（§1.6 第一步）：列元素是堆 Variant 的指针，tick 内解包
// Dictionary 读写字段。POD 热字段列（schema 注册）是后续优化项。
// 直写列不产生变更事件——需要变更日志的写入用 ecs_modified_id 手动触发
// （见开发指南）。

#pragma once

#include <godot_cpp/variant/variant.hpp>

#include <flecs.h>

// 框架基类：纯 C++ 抽象接口，不注册到 GDScript
class GF_EcsNativeSystem {
public:
	virtual ~GF_EcsNativeSystem() {}

	// 系统每帧 tick。it 已按注册时的 read_keys 顺序填充好组件列，
	// 子类用 ecs_field_w_size(it, sizeof(Variant *), index) 取列。
	virtual void tick(ecs_iter_t *it, double delta) = 0;
};

// 工厂函数签名（使用方实现，new 出系统实例）
typedef GF_EcsNativeSystem *(*GF_EcsNativeSystemFactory)();

// 注册表 API（实现在 gf_ecs_native_system_host.cpp）
bool gf_ecs_native_system_register(const char *p_name, GF_EcsNativeSystemFactory p_factory);
GF_EcsNativeSystem *gf_ecs_native_system_create(const char *p_name);

// 使用方注册宏：在扩展的任意 .cpp 顶层使用（自带分号）。
// 例：
//   GF_NATIVE_SYSTEM_REGISTER(MoveNativeSystem,
//       []() -> GF_EcsNativeSystem * { return new MoveNativeSystem(); })
#define GF_NATIVE_SYSTEM_REGISTER(name, factory_fn) \
	static const bool gf_native_system_registered_##name = \
			gf_ecs_native_system_register(#name, (factory_fn));
