# 性能优化路线图（戴森球计划对照）

## 概述

本文档定义框架层的性能优化路线，思路对照戴森球计划（DSP）的六大优化手段：
固定逻辑帧、DOP 数据导向存储、GPU 化、多线程、存档 = 种子 + delta、性能面板。

驱动证据来自 survival 项目（本框架的当前主要使用方）的 9 万实体规模实测：

- 每渲染帧的 ECS tick 中，热点系统对每个被处理实体执行
  `new Component()` + `get_component()` 字典查找 + ECB 写回
  （1.7 万实体时每帧约 142 次组件分配，GC 压力主源）；
- 存储层是 `Dictionary` + `Array[Variant]` 的 SparseSet，组件本体是 `RefCounted` 堆对象；
- Query 的 `execute()` 每行分配 Row 对象 + 组件字典（`ecs_query_plan.gd` 注释自认
  「周期性 GC 尖峰」）；
- 存档是全量 JSON 序列化，无增量、无「种子 + 改动」模式；
- 多线程 job 系统已就绪但 ECS 零集成；性能观测只有 fps/帧时间计数。

**原则（对齐 CLAUDE.md 边界）**：本文档只含**机制**，不含任何具体游戏业务规则。
组件字段长什么样、哪些数据需要存档、面板显示什么子系统——
均由使用方（游戏层）在其对应文档中定义。

## 通用性边界（2026-08 修订）

本文档的驱动证据来自大世界生存建造类使用方（survival），但框架定位是
**Godot 2D 通用游戏框架**。每个机制件进框架前必须过三问：

1. **换一个品类还用得上吗？**——变更日志（脏标记/增量索引）对任何 ECS
   使用方有用；chunk 卸载对 2D 平台/音游/卡牌没有意义；
2. **API 形状是否携带品类假设？**——`perf_stats("子系统名")` 没有假设；
   `entities_in(region)` 携带「世界按区域切块」的品类假设；
3. **不注册是否零存在感？**——可选模块的最低门槛（不注册不占资源、
   不增加认知负担）。

按此标准盘点：

| 条目 | 判定 | 处置 |
|------|------|------|
| §1.1/§4 零分配遍历/性能观测 | ✅ 通用 | 已交付 |
| §1.4/§3.1 变更日志/delta | ✅ 通用 | 已交付 |
| §3.2 DELTA 策略 / §3.3 命令日志 | ✅ 通用 | 已交付 |
| §3.2 SEED_PATCH 策略 | ⚠️ 边缘（程序化生成专用，三策略之一 opt-in） | 已交付 |
| §3.4 生成协议 | ⚠️ 程序化生成专用 | 只留接口本身（SEED_PATCH 配套） |
| **§5 区域管理** | ❌ 大世界流式加载专用 | **下沉到使用方**，框架不实现 |
| §2 固定步长 / §6 多线程 / §1.6-§1.7 C++ | ✅ 通用 | 按路线图推进 |

**框架收在哪里**：ECS + 存档 + 命令 + 调度 + 观测的**通用机制层**；
大世界专属的一切（区域卸载、程序化生成编排）在使用方 game/ 层生长，
缺什么补什么时框架再吸收被验证的通用件。

## 与使用方文档的对应关系

| 本文档条目 | 使用方（survival）对应条目 |
|-----------|--------------------------|
| §1.1 零分配遍历 | 游戏文档 §1（GrowthSystem SoA 缓存依赖 `max_entity_id()`/`execute_entities()`） |
| §1.4 变更日志 | 游戏文档 §1.5（缓存迁移目标）、§6（patch 捕获） |
| §1.6/§1.7 C++ 底座 | 游戏文档 §11（热点系统下沉） |
| §2 固定步长 | 游戏文档 §5.1 |
| §3 存档增量引擎 | 游戏文档 §6（WorldPatch 模型接入） |
| §4 性能观测 | 游戏文档 §8（子系统注册） |
| §5 区域实体管理（已下沉） | 游戏文档 §7（chunk 卸载 + 回放，使用方层实现） |
| §6 多线程 | 游戏文档 §10（顺序与局部性约束） |

> 注：上表章节号以 survival 项目内部文档当前版本为准，其章节重排后需同步本表。

---

## 1. ECS 存储与遍历 DOP 化

对照 DSP 的 DOP：对象属性拆成紧密数组（SoA）、热点路径避免哈希容器、主动管理 GC。
这是框架层最重要的性能工作，分四个梯度推进——**每个梯度都是独立可交付的**，
后一梯度依赖前一个的 API 形态但不必等前一个完全落地。

### 1.1 零分配遍历（收尾提交）

**现状**：`ecs_query_plan.gd` 的 `execute()` 对每个候选实体分配
`GF_EcsQueryRow` + 组件字典（`ecs_query_plan.gd:137-148`），并有多次 `type_id_of()`/
`get_storage()` 字典查找。轻量路径已开发完成但**未提交**：

- `execute_entities()`：只返回 `PackedInt64Array` 的零分配遍历（`ecs_query_plan.gd:21-70`）；
- `max_entity_id()`：`ecs_world.gd:66-67`，供使用方做分帧游标扫描（
  「扫描 `(cursor, max_entity_id()]` 区间，避免周期性全量 query 的规模级尖峰」）。

survival 的 GrowthSystem 游标扫描**已经依赖**这两个 API（未提交状态在两处工作副本
同步存在）。

**方案**：
1. 提交两处修改（走框架 Git 工作流：main 分支提交 + test 分支合并补测试）；
   提交前把 `execute_entities()` 内层循环的 `registry.type_id_of(with_type)`
   预解析到循环外（`ecs_query_plan.gd:53`），消除每实体×每类型的字典查找——
   零分配路线的字典查找残留会让 benchmark 对比失真；
2. 测试覆盖：`execute_entities` 的 with/without 过滤正确性、空结果、
   `max_entity_id` 在 spawn/despawn 后的单调性（optional 对 entities-only
   查询是 no-op，不参与过滤，不作为测试项）；
3. `docs/manual/api-reference/ecs/` 补充 API 文档，明确「热路径用
   `execute_entities()` + 游标，`execute()` 留给冷路径」的指引。

**验收**：main + test 分支双绿；benchmark 对比 `execute()` vs `execute_entities()`
在 1 万实体下的分配计数（后者应为 0）。

### 1.2 Query 行复用（对象池）

**状态（2026-08 暂缓）**：§1.1 + §4 交付后使用方热点系统分配已归零；残余分配
（其余系统每帧 Row/字典）在 RefCounted 即时引用计数下是微秒级开销，需 §4 数据
证明其进入帧预算前列（或实体规模逼近 9 万）才值得投入。本项是阶段 C（原生后端）
前的过渡优化，C 启动即作废。重新评估触发器：§4 数据在 survival 侧采集完成、
或 C 排期明确。以下方案保留备查。

**现状**：`execute()` 的 Row/Dictionary 分配是每 tick 周期性 GC 尖峰（使用方即使
走了 `execute_entities()`，其余系统仍在用 `execute()`）。

**方案**：`GF_EcsQueryRow` 内部加池——Row 对象与组件字典按 query plan 复用，
`execute()` 返回的 Row 在下次 `execute()` 前有效（文档明示生命周期约束，
同 `get_row(i)` 的既有约定）。可选 API：`execute_pooled()` 返回稳定引用，
避免 `count()`/`get_row(i)` 的多次索引访问。

**风险**：Row 被使用方存留越过下一次 execute 会产生别名 bug——用「execute 返回
只读快照语义」的文档 + 测试约束；若发现使用方普遍存留，改为 Row 内容拷贝池
（只省对象头分配，收益减半）。

### 1.3 组件对象池

**状态（2026-08 暂缓）**：同 §1.2——C++ 底座前的过渡优化，且与使用方组件缓存
互斥（见下文「与使用方现状的互斥」），上线需协调缓存撤除。待 §1.4 变更日志
落地（缓存有替代品）后再评估，或随 C 排期明确直接跳过。以下方案保留备查。

**现状**：热点系统每 tick「new 组件 → 字段拷贝 → ECB set」的循环中，
`new Component()` 是不可避免的（ECB 版本递增需要新实例）。但旧实例在 ECB apply
后立即可回收——**组件是 RefCounted，refcount 归零才释放，无复用路径**。

**方案**：`GF_EcsCommandBuffer.set_component()` 应用时，被替换的旧组件**不立即释放**，
进入框架维护的 per-type 池（`ComponentPool`）；`GF_EcsWorld.create_component(type)`
从池取或 new。规则：

- 池只在 ECB apply 路径回收（保证写入侧不持有池中实例）；
- 池容量上限 + 懒清空（防极端实体数下的内存驻留）；
- 组件 `reset()` 钩子（默认为字段归零，使用方可重写）。

**收益**：热循环的堆分配从「每 tick N 次 new + N 次释放」降为「首次 N 次 new +
之后 0 次」——GC 压力从「高频小对象分配」变为「稳态零分配」。

**风险**：池中实例被引用计数残留（使用方持旧引用未释放）会破坏复用语义——
文档明示「ECB 应用后旧组件引用立即失效」（框架既有约定，见使用方系统注释），
并提供 debug 断言（DEBUG 构建下检测池中实例 refcount > 1）。

**与使用方现状的互斥（上线前置条件）**：使用方当前靠「缓存持有组件引用」绕行
变更日志缺失（§1.4），而缓存中的旧组件引用会让池回收变成悬空引用——DEBUG 断言
只能报错不能救场。**组件池与使用方组件缓存互斥**：池化上线前使用方必须撤除
组件缓存，缓存的替代品是 §1.4 变更日志。因此池化与变更日志要么同步交付，
要么明确声明「池化落地日 = 使用方缓存模式废弃日」。这是 §1.3「独立可交付」
的例外。

### 1.4 变更日志（change log / Added / Changed / Removed tick）

**现状**：框架 ECS 无变更日志，`spatial_index_sync_system.gd:25-26` 明说
「快照镜像字典是组件版本号的等价物（框架 ECS 尚无 Added/Changed tick）」。
使用方靠「快照镜像 diff」和「max_entity_id 游标」绕行。

**为什么是地基**（一石四鸟）：
1. **增量存档**（§3.1）——没有变更日志，delta 只能靠全量快照 diff（O(全量)，失去意义）；
2. **渲染脏标记**——使用方渲染器不再需要周期性全量扫描读组件，改为消费 Changed 列表；
3. **模拟免扫描**——使用方热点系统不再需要游标扫描（1.1 的绕行），
   直接消费 Added/Removed 列表维护缓存；
4. **预测回滚**（RuntimeBridge）——现有快照栈可改为增量 diff。

**方案**（单帧环形缓冲，不做持久化）：

```gdscript
## 世界级变更日志（单帧生命周期，tick 前清空）
## 消费者按需订阅（性能观测/渲染/存档各取所需）
class_name GF_EcsChangeLog

## 帧内变更记录；spawn/despawn 记 entity id，组件变更记 entity + type
var added_entities: PackedInt64Array
var removed_entities: PackedInt64Array
var component_changes: Array[Dictionary]   # {entity, type_id, component}（池化）
```

- `GF_EcsWorld` 的每次 mutation（spawn/despawn/add/set/remove）在 `_version` 递增之外
  追加日志条目；ECB apply 时批量追加；
- 消费者（使用方系统）通过 `world.change_log` 读取，框架不定义消费时序——
  **消费语义由使用方决定**（文档给三种消费模式的示例：增量索引维护、
  脏标记收集、存档 delta 累计）。

**与 1.1 的关系**：变更日志落地后，`execute_entities()` + 游标不再是唯一解，
但保留（变更日志消费方需要实体列表时仍比全量 query 便宜）。

**与 1.6 的关系**：GDScript 版 `GF_EcsChangeLog` 与原生后端提供**同构 API**
（同一套 Added/Removed/Changed 语义与消费方式），使用方系统代码不感知后端差异；
Flecs 集成形态下由 change detection 承载，§1.6 交付时用现有测试套件对拍两种
后端的变更日志一致性。

### 1.5 字段级列存储（GDScript 探路，明确收益边界）

**状态（2026-08 降级为 API 设计参考）**：使用方无列存储反馈、C 排期未定——
GDScript 版列存储不实现。本节保留作为 §1.6 原生后端的 API 形态参考
（schema 声明、`get_field` 列读语义在 C++/Flecs 版保持同构，使用方无迁移成本）。

**现状**：`ecs_sparse_set_storage.gd` 是「每组件类型一个 `Dictionary` sparse +
`Array[Variant]` dense」；可选 `ecs_archetype_storage.gd` 有 archetype 分组 +
列式 `Array`（非 PackedArray），`_find_archetype` 线性扫描，默认不用。

**方案**：在 SparseSet 后端上加**可选列存储**：使用方声明组件的热字段 schema
（`register_columns(Type, ["field_a", "field_b"])`），存储为该类型的这些字段维护
`PackedArray` 列；`get_field(entity, Type, "field_a")` 走列读（O(1) 无箱），
其余字段走原组件对象路径。

**诚实边界（必须写进文档）**：GDScript 下列存储的收益**有限**——
每字段访问仍是跨列索引 + Variant 语义，`PackedArray` 写入有按值拷贝开销；
真正的 DOP（紧凑内存、SIMD、缓存友好）**只有 C++ 能做到**（§1.6）。
本节定位是：
1. **API 形态探路**——列存储的访问语义在 GDScript 版先定型，
   C++ 版（§1.6）保持同 API 面，使用方无迁移成本；
2. **对「组件对象不存在但字段存在」的中间态做验证**——为 C++ 版验证
   「列是真值、组件对象是冷快照」的模式。

（本节已降级为 API 设计参考，不实现，见本节状态。）

### 1.6 GDExtension 存储后端（C++，长期）

**为什么必须 C++**：GDScript 的性能天花板在于——每实体组件是堆对象（无 SoA 布局）、
字典查找、Variant 装箱、GC。戴森球 DOP 的「紧密排列数组 + 缓存友好 + 主动内存管理」
在 GDScript 内不可达。这是框架层唯一的根本解。

**首选路线：Flecs 集成（2026-08 调研结论）**：[Flecs](https://github.com/SanderMertens/flecs)
（MIT，C99 API，amalgamated 单文件分发）是现成 C++ ECS 库中的最佳候选——
能力面与本路线图逐条对应，官方仓库自带 Godot 示例：

| 路线图需求 | Flecs 能力 |
|-----------|-----------|
| §1.6 列式存储 | sparse set 列式存储（库本体） |
| §1.4 变更日志 | change detection（monitor/on_set） |
| §6.2 多线程模拟 | 内置线程池调度器 |
| §2/§3.3 决定论 | 官方决定论模式 |
| §3 快照 | 内置 snapshot |
| 纯代码分发模式 | amalgamated 单文件随仓库分发，使用方 SConstruct 编译 |

候选对比：

| 候选 | 评估 |
|------|------|
| Flecs 库本体（集成） | ✅ 首选：成熟度最高、能力面全覆盖、MIT、C API 稳定 |
| godot-glecs（Flecs 现成绑定） | ⚠️ 仅作参考实现：预编译只覆盖 Linux/Windows（无 macOS）、无 license 文件、API 面是 Flecs 原生语义而非框架 API |
| EnTT | ⚠️ 备选：header-only 性能天花板略高，但模板 API 跨 GDExtension 边界胶水成本最高、无自带多线程调度/变更检测、Godot 集成先例为零 |
| 自研窄化 | 兜底：只做列存储 + 查询游标，不做完整 ECS（门面适配成本超预期时启用） |

**用 Flecs 也不能省的自研部分**：

1. `GF_EcsWorld` API 兼容门面——GDScript API 与现有测试套件保持不变，对拍验证。
   语义适配点：Flecs 实体 index 复用（index+generation）vs 框架「ID 单调不复用
   + max_entity_id 游标」；框架组件是 RefCounted，Flecs 列中存 godot-cpp Variant
   （热字段走 schema 注册为原生 POD 列，冷数据走组件对象——§1.5 的
   「列是真值、组件对象是冷快照」模式由 Flecs 承载）；
2. 快照/存档序列化对接现有 save 模块（Flecs snapshot 不管 JSON 格式与版本迁移）；
3. 编译链 + 三平台 CI（分发策略见下）；
4. §1.7 的使用方原生系统开发指南（即「Flecs system 开发指南」）。

**分发策略**（C++ 底座引入后框架分发模式的澄清）：框架保持「Git 仓库纯代码」
分发——C++ 源码（Flecs amalgamated + godot-cpp）随仓库走 submodule/复制，
使用方本地 SConstruct 构建；**不承诺预编译二进制**（跨 Godot 版本 ABI 不稳定，
维护成本不可控）。不引入编译链的使用方留在 GDScript 后端（阶段 C 本身 opt-in）。

**工作量对比**（单人全职）：Flecs 集成约 2-3k 行胶水 / 2-3 个月；自研完整后端
约 6-10k 行 C++ / 3.5-5.5 个月。是否走 Flecs 由 §1.8 探针实测决定，开工前不拍板。

以下「方案」描述两种形态共有的 API 面（原生存储后端 / 查询游标 / 变更日志 /
批量 API）——自研形态照此实现，Flecs 形态将其映射到 Flecs 能力。

**方案**：

```text
GDScript 层（不变）                    C++ 层（新增）
─────────────────────                ─────────────────────
GF_EcsWorld                           原生存储后端
  ├─ spawn/despawn/add/set/get          ├─ 组件列（每类型每字段连续内存）
  ├─ GF_EcsQueryPlan（API 不变）         ├─ 查询游标（零分配遍历）
  └─ storage_backend 枚举（已有切换位）   ├─ 变更日志（追加写入原生缓冲）
                                        └─ 批量 API：set_component_batch()
```

- 组件字段 schema 数据驱动：使用方注册字段表（GDScript 侧声明，C++ 端建列），
  GDScript `get_component` 仍返回组件对象，**热路径走 C++ 游标**。
  `get_component` 的两条路径及成本边界（诚实声明：C++ 后端的收益只在原生热路径，
  不在 GDScript 侧）：
  - **缓存路径（默认）**：每实体每类型缓存组件对象 + 版本号失效，命中时 O(1)
    返回稳定引用，写入侧递增版本号使缓存失效；
  - **组装路径**：每次调用从列组装组件对象 = 每次堆分配，冷路径可能**慢于**
    现状字典存储，仅用于低访问频率类型；
- **边界开销的硬约束**：跨 GDExtension 边界的单次调用开销要求「热循环整体在 C++ 侧」
  ——这正是 §1.7 存在的理由，两者必须一起交付才有收益；
- `storage_backend` 枚举（`ecs_storage_index.gd:7-12` 已预留）加 `NATIVE` 项，
  运行时切换 + 回归测试对比两种后端的行为一致性（现有测试套件直接复用）。

**分两步交付**：先做「存储 + 查询下沉」（GDScript 系统仍可跑，行为一致），
再做 §1.7「系统执行环境」——第一步单独交付时**不承诺性能收益**，只有正确性。

### 1.7 GDExtension 系统执行环境

**现状**：`GF_EcsSystem.on_tick` 是 GDScript 虚方法，主线程解释执行。

**方案**：提供原生系统基类——使用方系统注册为「字段 schema + 原生 tick 回调」
（C++ 实现，GDScript 定义声明）：

```text
GF_EcsNativeSystem（C++ 基类，GDExtension 注册）
  ├─ 声明组件字段 schema（与 §1.6 列存储共用）
  ├─ tick()：在 C++ 侧直接游标遍历列 → 纯算术推进 → 批量写回列
  └─ 离散事件回调（GDScript）：阶段切换/死亡等低频逻辑仍回 GDScript 写
```

**归属**：框架提供执行环境（基类 + 调度接入），**具体系统逻辑由使用方用 C++ 编写**
（框架不含任何业务规则）。框架 docs 提供完整的「原生系统开发指南」：
编译链（SConstruct/CMake）、字段注册、事件跨界、调试。

**收益预期**：热点系统的 tick 循环从「解释执行 + 每实体字典查找 + 堆分配」
变为「原生列遍历 + 寄存器运算」，预期 10x~100x 量级（按字段数和分支复杂度波动），
这是 9 万实体场景从「每帧预算紧张」到「余量充足」的根本跨越。
**前提条件**：热点循环内 GDScript↔C++ 边界调用次数 O(1)（循环整体在 C++ 侧）、
热字段走原生 POD 列、无 GDScript 回调混入热路径。
**验收拆分**：第一步（存储 + 查询下沉）只验收「行为一致 + 回归测试全绿 +
原生游标正确性」，不验收性能；第二步（执行环境）验收「tick 预算占比下降 ≥ 10x
或降至 3% 以下」。

### 1.8 GDExtension 探针（阶段 B/C 之间的 gate）

阶段 C 投入最大、不确定性最高，启动前用最小探针验证关键假设。探针以
**Flecs 最小集成**为形态（也是 §1.6 选型的数据来源）：

1. **编译链跑通**：Flecs amalgamated + godot-cpp，macOS 本地 + 三平台 CI；
2. **最小集成**：实体/组件 Variant 列 + 原生查询游标 + `GF_EcsWorld` 门面最小子集；
3. **三个实测数据**（回填 §1.6 的「边界开销硬约束」）：
   - 单次 GDScript↔C++ 边界调用开销（μs 级）；
   - 1 万实体查询：Flecs 原生游标 vs 现有 SparseSet 的耗时倍数；
   - Flecs change detection 能否等价替换 §1.4 的变更日志语义（含消费 API）；
4. **go/no-go**：数据达标 → 阶段 C 走 Flecs 集成；边界开销推翻「热循环整体在
   C++ 侧」假设、或门面适配成本超预期 → 降级为自研窄化（只做列存储 + 游标），
   或推迟阶段 C。

**参考实现**：[godot-glecs](https://github.com/GsLogiMaker/godot-glecs) 的 `gd/`
绑定层与 Flecs 官方仓库的 Godot 示例（不直接依赖：预编译无 macOS、无 license、
单作者项目）。

**探针成本**：约 1 周（编译链踩坑占大头）。§7 触发线未到之前，探针是阶段 C 的
全部投入。

---

## 2. 固定步长模拟调度

对照 DSP 的「渲染帧与逻辑帧分离」：逻辑帧锁固定 Hz（60 UPS），整数帧计时保证决定论。

**现状**：`GF_Scheduler` 有 TickGroup 分组（`PHYSICS` 固定 60Hz / `FRAME` / `SIMULATION` /
`UI` / `SAVE` / `DEBUG`）和 `register_interval` 节流（内部有 accumulator，但只有
节流语义，无固定步长推进/追帧上限/整数 tick 计数）；`GF_EcsScheduler` 绑在
SIMULATION 组（每渲染帧、可变 delta）。使用方靠系统内部分片近似节流。

**方案**：

1. **`GF_Scheduler` 加固定步长组**：`TickGroup.SIMULATION_FIXED`（accumulator 模式，
   `fixed_step_seconds` 可配，默认 1/30）：渲染帧内 accumulator 累计 delta，
   每次 tick 消耗一个固定步长，追帧上限（如单帧最多 3 步，防螺旋死亡）；
2. **逻辑时钟**：固定组 tick 时暴露 `tick_index: int`（单调递增）+ 组内 delta 恒为
   `fixed_step_seconds`——使用方系统以「整数 tick 计数」计时（3 秒 = 90 tick @30Hz），
   决定论由「固定步长 + 整数计数」保证，与渲染帧率解耦；
3. **`GF_EcsScheduler` 支持绑定固定组**：Simulation 组新增 `fixed` 子组（或独立绑定参数），
   系统声明 `fixed_tick = true` 即入固定组；
4. **分片与固定步长的职责分离（文档化）**：固定步长管「推进频率」（决定论），
   使用方内部分片管「单帧峰值均摊」（性能）——两者正交，框架不代劳分片；
5. **与 PHYSICS 组的分工（文档化）**：PHYSICS 由 `_physics_process` 驱动，
   步长受 `physics_ticks_per_second` 控制且与物理插值耦合；SIMULATION_FIXED
   的意义是逻辑步长独立于物理步长可配（默认 1/30）+ 追帧上限语义。
   PHYSICS 继续服务物理，SIMULATION_FIXED 服务决定论模拟。

**验收**：60fps 与 120fps 渲染下跑同一模拟，固定组 tick 次数一致、状态逐 bit 一致
（使用方提供等价性用例）。

---

## 3. 存档增量引擎

对照 DSP 的「存档 = 种子 + delta」：世界由种子程序化生成，存档只记玩家改动。

### 3.1 增量语义补全

**现状**：`ecs_snapshot_applier.gd:53-70` 的 `apply_delta()` 只 upsert 不删除；
`docs/manual/advanced/ecs-snapshot-and-replay.md` 的「增量快照」是伪代码
（注释写明「通过 ECS 的变更日志构建 delta」，而变更日志不存在）。

**方案**：§1.4 变更日志落地后，
`GF_EcsDeltaBuilder`（从变更日志构建 `{upserts, removes}`）+ `apply_delta()` 补删除语义
（实体移除 + 组件移除）。测试覆盖 upsert/remove 混合、空 delta、乱序应用。

### 3.2 SaveStrategy 三策略落地

**现状**：`runtime/save_strategy.gd` 是 9 行抽象基类（只返回 provider 类型），
Local/Remote/Hybrid 未实现；`modules/save/` 是全量 JSON 序列化 + 版本迁移链
（机制完好，但模式只有 FULL 一种）。

**方案**：SaveStrategy 枚举三模式，使用方在装配时声明：

| 模式 | 内容 | 适用 |
|------|------|------|
| `FULL` | 现状：全量快照 JSON + 版本迁移链 | 小型存档 / 兼容模式 |
| `DELTA` | 变更日志累计 → 增量存档（基底快照 + 追加 delta，定期压缩） | 大世界、频繁存档 |
| `SEED_PATCH` | 世界种子 + 命令日志/改动记录，回档 = 重置 + 重放 | 确定性程序化世界 |

- `SEED_PATCH` 的框架侧职责：**重放编排**（重置世界 → 注入种子 → 调用使用方
  生成器 → 按序应用改动记录 → 恢复其余 saveable），不改动使用方的生成器逻辑；
- 改动记录的**内容格式由使用方定义**（框架提供 `GF_IPatchRecord` 接口 + 默认
  命令日志实现，见 §3.3）；
- 版本迁移链三种模式共用（存档头统一带模式标识 + 版本号）。

### 3.3 命令日志持久化

**现状**：Command 是框架一等公民（`runtime/command_bus.gd` + `ICommand`），
但总线不记录历史。

**方案**：`GF_CommandLog`——命令总线可选开启记录，按序落盘（append-only），
`SEED_PATCH` 模式下的改动记录默认实现。回档重放 = 按序重发命令。
对命令的约束文档化：**确定性命令**（同参数重放结果一致，禁止读时钟/随机源，
随机改为「命令携带随机数或种子派生」）才可入日志；使用方在 Command 上标注
`deterministic` 标志，非确定命令在日志模式下运行时报错（DEBUG）。

**C++ 后端落地后追加**（决定论风险集中在原生层——GDScript 解释器是统一实现、
跨平台一致性好）：原生层禁止宽松浮点优化（如 `-ffast-math`），浮点归约顺序固定
（禁止依赖线程数的动态划分）；SEED_PATCH 重放验收包含「原生后端 × GDScript
后端」同 seed 对拍（浮点容差内一致）。

### 3.4 生成协议（仅接口）

**状态（2026-08 降权）**：按需生成编排、确定性审计均随 §5 下沉到使用方。
框架只保留接口本身——`GF_IWorldGenerator` 是 SEED_PATCH 存档（§3.2）
完整性的配套件：重放编排需要「按种子生成世界」的协议入口。

```gdscript
## 确定性世界生成器协议（使用方实现，SEED_PATCH 重放编排的生成入口）
class_name GF_IWorldGenerator

## 同 (seed, region) 必须产生完全相同的结果（跨平台、跨版本）
func generate(seed: int, region: Rect2i) -> Array[Dictionary]
```

- 接口由使用方实现，`GF_SeedPatchSaveStrategy.generator_hook` 接线后
  SEED_PATCH 回档 = 重置 → 按种子生成 → 应用改动记录；
- `regenerable_component_types()`（可重算组件声明）随 §5 下沉——
  组件可重算性的识别属于使用方语义，框架不定义。

---

## 4. 性能观测设施

对照 DSP 的 P 键性能面板：各子系统延迟统计，用户可自助定位卡顿。

**现状**：`modules/debug/debug_service.gd` 只有 fps/帧时间计数 + 空的面板注册表
（`panels: Dictionary` + `register_panel()`），无面板实现、无子系统计时；
`GF_Scheduler` 无 TickGroup 耗时统计。

**方案**：

1. **子系统计时 API**：`GF_PerfScope`（scoped timer，tick 边界自动计）+
   `DebugService.subsystem_stats(name)` 返回环形缓冲（最近 N 帧的 avg/max/尖峰帧号）；
2. **Scheduler 集成**：每个 TickGroup 的 tick 耗时自动入统计（opt-in：
   面板/统计未注册时不开计时，注册后每个 TickGroup 一个 scope）；
3. **内置调试面板壳**：框架提供 `GF_DebugPanel` 基类（复用 UI 模块面板系统）+
   默认渲染（子系统列表 + 每行 avg/max + 可折叠），使用方注册子系统名与按键绑定；
   面板视觉由使用方自定义（框架壳不带游戏美术）。
4. **线程统计接入**：`GF_ThreadingService` 的已有统计（`threading_service.gd:43-54`）
   注册为固定子系统项。

**验收**：注册 3 个子系统的示例项目，面板显示 avg/max 与尖峰帧号；
Scheduler 各 TickGroup 耗时可见；关闭面板时计时开销 < 0.01ms/帧。

---

## 5. 区域实体管理（下沉到使用方）

**状态（2026-08 下沉）**：chunk 卸载/回放是大世界流式加载专用机制，
按「通用性边界」三问判定，框架不实现。使用方可用框架已有通用件自行组装：

- `GF_GridIndex` 的 miss 回调：查询未命中时触发（`spatial_grid_index.gd:71-76`），
  「chunk 未生成 → 触发生成请求」的游戏语义由使用方回调实现——框架只提供挂载点；
- 快照/增量（§3.1）：`GF_EcsSnapshotBuilder` + `GF_EcsDeltaBuilder` +
  `apply_delta` 可做区域级快照与回放；
- 变更日志（§1.4）：实体增删/组件变更的消费入口，卸载时消费
  removed_entities 清理外部结构（如空间索引）。

**使用方组装模式**（参考流程，非框架 API）：

1. 卸载：按使用方自身分区逻辑收集实体集合 → 区域快照 + 改动 patch
   （使用方格式）→ despawn → 清外部索引；
2. 回放：miss 回调触发 → 使用方生成器重建 → 快照/改动应用。

卸载策略（距离/延迟/可卸载判定）、可重算组件声明、patch 内容格式——
全部由使用方定义。缺什么补什么时，被验证为通用的件框架再吸收。

---

## 6. 多线程路线

对照 DSP 两代多线程框架：一代「阶段并行」已完成（本框架 job 系统），
二代「动态任务分配 + 缓存命中率优先」需要 C++ 底座。

**现状**：`GF_ThreadingService` 是完整 job 系统（优先级/取消/超时/重试/统计/
Mutex 回传），使用方已用于后台地形生成；但 ECS 与线程零集成，
文档明确禁止子线程读写 ECS World。

**方案**：

1. **一代收尾**（✅ 已交付）：
   - job 统计接入 §4 性能观测——`GF_DebugService.attach_threading_service()`
     便捷接线，每帧自动记录 `threading.submitted / queue_peak /
     avg_duration_ms` 等子系统项；
   - 「纯数据任务」提交模式文档化——
     [pure-data-jobs.md](../../manual/best-practices/pure-data-jobs.md)
     （submit → pump → 回收 + 四硬约束 + 统计观测指标）；
2. **二代（C++ 前置，远期）**：§1.6/§1.7 落地后，模拟循环可在原生层
   并行化——按区域分块（§5 的区域分组复用为任务粒度）、每块独立游标遍历、
   每线程局部 ECB 合并回主线程。**合并冲突语义**：分块保证写隔离（组件写入
   不跨块）；跨块写入的组件类型由使用方声明为「只读共享」或「冲突降级单线程」；
   合并时检测到同实体同组件多写（DEBUG 断言 + 发布版按 tick 序最后写胜），
   冲突统计接入 §4 观测。**顺序不可颠倒**：没有紧凑数据（§1.6），
   并行打不满带宽——DSP 自己也是先 DOP 后多线程。

**明确不做**：GDScript 层「并行 system」——共享 World 无锁保护 + 解释器开销，
收益为负。若使用方在 C++ 底座前有多线程模拟需求，用「只读快照进后台计算 +
  主线程写回」模式（快照 §3 已有），文档写明其拷贝成本边界。

---

## 7. 路线图

```
阶段 A（收尾，main 分支提交，短期）
  ✅ §1.1 零分配遍历提交（已交付）
  ✅ §4 性能观测（计时 API + 面板壳）（已交付）
  ⏸ §1.2 Row 池 / §1.3 组件池（暂缓：待 §4 数据证明残余分配进入帧预算前列，
    或 C 排期临近时直接跳过——C++ 底座前的过渡优化，详见 §1.2/§1.3 状态）

阶段 B（机制件，中期）
  ✅ §1.4 变更日志（已交付）
  ✅ §3.1 delta 补全（已交付）
  ✅ §3.2 三策略（已交付）
  ✅ §3.3 命令日志（已交付）
  ⏳ §2 固定步长调度（通用件，下一步）
  ⏳ §3.4 生成接口（仅接口本身，SEED_PATCH 配套）
  ⬇ §5 区域管理（下沉到使用方——大世界专用，见「通用性边界」）
  ⬇ §1.5 列存储（已降级为 §1.6 的 API 设计参考，不实现）
  ✅ §6 一代收尾（线程统计接线 + 纯数据任务文档）

阶段 B/C 之间（gate）
  §1.8 GDExtension 探针（Flecs 最小集成 + 三个实测数据 → 阶段 C go/no-go）

阶段 C（C++ 底座，长期，战略投入）
  §1.6 GDExtension 存储 ──► §1.7 原生系统执行环境 ──► §6.2 并行模拟
```

依赖关系要点：
- **变更日志（§1.4）是阶段 B 的地基**——增量存档、渲染脏标记、
  模拟免扫描全部依赖它；
- **观测先行（已按此执行）**：§1.2/§1.3 池化暂缓——未用数据证明前不上
  API 生命周期破坏性变更（Row 别名、组件引用失效）；§4 数据（survival 侧采集）
  或 C 排期是重新评估的触发器；
- **通用性边界（2026-08 修订）**：机制件进框架前三问（换品类是否仍有用 /
  API 是否携带品类假设 / 不注册是否零存在感）；§5 区域管理据此下沉到使用方；
- §2 固定步长独立于 ECS 改造，可与阶段 A 并行；
- 阶段 C 的投入产出要和使用方规模一起评估（触发线建议：单机实体量 ≥ 10 万
  或 tick 预算占比 ≥ 30% 时启动），形态（Flecs 集成 / 自研窄化 / 推迟）
  由 §1.8 探针实测决定，开工前不拍板。

**工期参考**（单人全职）：阶段 A 约 2-3 周；阶段 B 约 7-10 周；探针约 1 周；
阶段 C 约 2-3 个月（Flecs 集成）或 3.5-5.5 个月（自研）；
完整流程约 5-8 个月。业余时间（2-3 小时/天）乘 2.5-3 倍。

## 8. 验收标准（阶段级）

| 阶段 | 验收 |
|------|------|
| A | 使用方（survival）热点系统分配归零（§1.1 已达成）；性能面板可显示子系统耗时（§4 已达成）；§1.2/§1.3 池化暂缓，不阻塞阶段 B |
| B | 使用方存档从 FULL 切换 SEED_PATCH：体积/加载时间下降一个数量级（区域卸载/回访由使用方层自行实现，§5 已下沉） |
| B/C gate | 探针三数据产出（边界开销 / 查询倍数 / change detection 等价性），阶段 C 形态定案 |
| C | 使用方 9 万实体场景：模拟 tick 从 GDScript 基线下降 10x+；固定步长 + 原生层决定论保持 |
