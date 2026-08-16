# 原生系统开发指南（§1.7 执行环境）

本文档指导使用方将热点 ECS 系统下沉为 C++ 原生系统。前置阅读：
[性能优化路线图](performance-optimization-roadmap.md) §1.6/§1.7，
[gdextension/README.md](../../../gdextension/README.md)（编译链）。

**适用场景**：实体量万级以上、tick 预算中系统耗时占前列（性能面板 §4 数据
定位）。基准参考：1 万实体 × Position+=Velocity·dt，GDScript 系统形态 vs
原生系统 **21.8x**（tests/benchmark/test_ecs_native_system_benchmark.gd，
验收线 10x）。

---

## 1. 架构

```text
GDScript 层                             C++ 层（编译进扩展 dylib）
─────────────────────                  ──────────────────────────
GF_EcsNativeSystemService               GF_EcsNativeSystem（基类，使用方继承）
  ├─ set_world(NATIVE world)               ├─ tick(it, delta)：热循环整体在 C++
  ├─ register_system(名字, 组件列表)        └─ 列访问：ecs_field_w_size（0-based）
  └─ bind_to_scheduler()                 GF_NATIVE_SYSTEM_REGISTER 宏
         │                                （dylib 加载时注册工厂）
         └─► GF_EcsNativeSystemHost（C++）
                ├─ 按名查工厂表实例化系统
                ├─ 按组件列表建 Flecs 多组件 query
                └─ tick_all(delta)：遍历系统执行
```

执行环境（基类 + 工厂注册 + 宿主 + 调度接入）由框架提供；
**系统逻辑由使用方用 C++ 编写**——框架不含任何业务规则。

---

## 2. 编写原生系统

使用方在 `gdextension/src/` 添加系统源文件（SConstruct 的 `Glob("src/*.cpp")`
自动纳入编译）：

```cpp
// gdextension/src/my_systems.cpp
#include <godot_cpp/variant/dictionary.hpp>
#include "gf_ecs_native_system.h"

using namespace godot;

class MyGrowthSystem : public GF_EcsNativeSystem {
public:
    void tick(ecs_iter_t *it, double delta) override {
        // 列索引 0-based（Flecs 4）：field 0 = 注册时第一个组件类型
        Variant **pos_col = static_cast<Variant **>(ecs_field_w_size(it, sizeof(Variant *), 0));
        Variant **vel_col = static_cast<Variant **>(ecs_field_w_size(it, sizeof(Variant *), 1));
        for (int i = 0; i < it->count; i++) {
            Dictionary pos = (*pos_col[i]);
            Dictionary vel = (*vel_col[i]);
            pos["x"] = double(pos["x"]) + double(vel["vx"]) * delta;
        }
    }
};

// 工厂注册：dylib 加载时自动执行，GDScript 按 "MyGrowthSystem" 引用
GF_NATIVE_SYSTEM_REGISTER(MyGrowthSystem,
    []() -> GF_EcsNativeSystem * { return new MyGrowthSystem(); })
```

要点：

- `tick` 的 `it->count` 是本批实体数，`it->entities[i]` 是实体 id（Flecs 原生
  id，非框架 id——原生系统在门面之下运行，不需要框架 id）；
- 列索引**0-based**（Flecs 4 的 `it->ptrs[index]` 直接下标；Flecs 3 的
  1-based 惯例在 v4 不适用）；
- 组件数据是 `Variant`（内容 Dictionary/基础类型），`double(dict["key"])`
  显式转换取值。

## 3. 调度接入（GDScript）

```gdscript
class_name MyGame
extends GF_AppBootstrap

func _assemble() -> void:
    var world := GF_EcsWorld.new(GF_EcsStorageIndex.StorageBackend.NATIVE)
    register(world)
    register(GF_EcsNativeSystemService.new())
    register(GF_EcsScheduler.new())  # 已有模式不变
    # ...

func _on_ready() -> void:
    var native := service(GF_EcsNativeSystemService)
    native.set_world(service(GF_EcsWorld))
    native.register_system("MyGrowthSystem", [MyPos, MyVel])
    native.bind_to_scheduler()  # SIMULATION 组，每渲染帧 tick_all(delta)
```

`register_system` 的组件列表顺序 = tick 内列索引顺序。列表用组件
class_name 引用，经 registry 解析为 type_key（与原生侧组件键一致）。

## 4. 语义边界（必须知晓）

### 4.1 Variant 浅共享

组件数据过边界是 **引用计数浅传递**：`add_component` 存入的 Dictionary
与调用方的 Dictionary 共享底层。循环添加时**每实体必须独立实例**：

```gdscript
# ❌ 全部实体共享同一底层字典，tick 写穿
var payload := {"x": 1.0}
for i in 10000:
    world.add_component(world.spawn(), MyPos, payload)

# ✅ 每实体独立
for i in 10000:
    world.add_component(world.spawn(), MyPos, {"x": 1.0})
```

（与 GDScript 后端同语义——框架不自动深拷贝。）

### 4.2 直写列不产生变更事件

原生系统直接改列内 Variant，**不触发变更日志**。消费方需要感知时，
在 tick 内对变更实体手动触发：

```cpp
ecs_modified_id(it->world, it->entities[i], comp_id);
```

（comp_id 可从 `it->ids[0]` 等取得。）需要变更事件的写入也可以留在
GDScript 层做（离散事件回调模式，见路线图 §1.7）。

### 4.3 Dictionary 读取不创建键

`double(dict["missing"])` 得 0（Godot Dictionary 读取不存在键返回 null，
不插入）；**写入**不存在键才创建。tick 内注意字段缺失时的默认值语义。

## 5. 调试

- **工厂名拼错/未链接**：`register_system` 返回 `ERR_NOT_FOUND`，错误消息
  提示检查宏注册与编译链接（见 §6）；
- **列类型错误**：`ecs_field_w_size` 的 size 与组件列不符时 Flecs 断言
  「mismatching size」——组件列恒为 `Variant*`（8 字节），固定用
  `sizeof(Variant *)`；
- **热循环正确性**：先小规模（1 万实体）跑
  `tests/benchmark/test_ecs_native_system_benchmark.gd` 的结果一致性断言
  （GDScript 档 vs 原生档锚点值相等）。

## 6. 常见问题

| 症状 | 原因 | 处置 |
|------|------|------|
| `register_system` ERR_NOT_FOUND | 工厂宏未执行 | 确认 .cpp 在 `gdextension/src/`（SConstruct Glob）且已重编 + Godot 重启加载新 dylib |
| tick 无效果 | 列索引 1-based 惯性 | Flecs 4 是 **0-based** |
| 数据串实体 | 共享 payload | 每实体独立字典（§4.1） |
| 编译报「incomplete type Variant」 | 头文件缺 variant.hpp | `#include <godot_cpp/variant/variant.hpp>` |

## 7. 参考

- 基类与宏：`gdextension/src/gf_ecs_native_system.h`
- 示例系统：`gdextension/src/example_native_systems.cpp`（MoveNativeSystem）
- 基准：`tests/benchmark/test_ecs_native_system_benchmark.gd`
- 调度服务：`modules/ecs/system/gf_ecs_native_system_service.gd`
