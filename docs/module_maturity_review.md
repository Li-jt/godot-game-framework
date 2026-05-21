# 框架模块成熟度评审

> 评审范围：`godot-game-framework` 当前 Framework 层全部模块。
> 目标：对照常见商业游戏框架、Godot 项目实践和 Unity/Unreal 风格的工程分层，识别当前框架中不成熟、风险较高或需要优先补齐的模块。

---

## 1. 总体结论

当前框架已经具备清晰的分层意识：启动装配、服务注册、配置、输入、UI、存档、资源、场景宿主、日志、事件、Runtime 模式等都有独立模块。作为 MVP 或早期项目底座，它的方向是正确的。

但对照市面上成熟的游戏基础框架，目前仍属于 **可用的早期框架**，不是完整生产级框架。主要差距集中在：

1. **策略层只有接口，缺少真实 Remote / Hybrid 实现**  
   `RuntimeService` 已经定义 Local / Remote / Hybrid，但 `Remote` 和 `Hybrid` 的命令、存档、网络、预测、回滚都还没有落地。

2. **Framework 能力和 Game 约定之间仍有若干“软连接”**  
   例如 UI 输入阻挡已经有机制，但 Game 层必须正确使用 `InputService`；Command pipeline 目前主要在 Game 层实现，Framework 还没有提供统一命令总线。

3. **数据访问层、网络层、资源层偏接口和占位**  
   有 Repository / UnitOfWork / NetworkClient 形态，但缺少真实 Provider、重试、超时、序列化、缓存失效、冲突解决等生产能力。

4. **测试和诊断能力不足**  
   框架级契约测试、模块自测、输入/UI 阻挡回归测试、Save 迁移测试还没有形成稳定测试矩阵。

5. **生命周期与错误恢复还比较简单**  
   启动失败清理有雏形，但服务之间的依赖图、热重载、场景切换中的资源释放、异步取消、安全销毁还没有系统化。

---

## 2. 模块成熟度概览

| 模块 | 当前成熟度 | 市面成熟框架常见能力 | 当前主要差距 | 优先级 |
|---|---:|---|---|---|
| Application / Installer | 3/5 | 依赖图、阶段化启动、失败恢复、可测试装配 | 依赖顺序硬编码，缺少依赖声明和启动阶段扩展点 | P1 |
| Core / OperationResult | 3.5/5 | 统一错误、上下文、错误链、可观测性 | 错误上下文较弱，缺少 trace/correlation id | P2 |
| Environment / AppConfig | 3.5/5 | 多来源配置、校验、环境覆盖、热重载 | 命令行/编辑器覆盖仍是预留，缺少 schema 化文档 | P2 |
| Logging | 3/5 | 多 sink、结构化日志、文件轮转、过滤、远程上报 | 同步写文件，缺少结构化输出和采样 | P2 |
| EventBus | 2.5/5 | 事件类型化、优先级、异步队列、生命周期绑定 | 字符串事件易错，缺少 payload 约束和安全派发 | P1 |
| Flow | 3/5 | 状态机、转场、守卫、历史、异步 loading | 状态较固定，缺少 transition hook 和 loading 任务编排 | P2 |
| Input | 3/5 | action map、上下文栈、UI gate、多设备、rebinding | 鼠标/手柄/触控抽象仍薄，缺少输入事件流和可配置绑定 | P1 |
| UI | 3/5 | 层级、生命周期、modal、输入阻挡、导航、ViewModel | 缺少 UI 导航、焦点管理、主题体系和数据绑定 | P1 |
| SceneHost / SceneFactory | 3/5 | 场景切换、异步加载、加载进度、过渡、生命周期钩子 | 当前同步加载，世界卸载只 queue_free，缺少加载状态和取消 | P1 |
| Scheduler | 2.5/5 | tick phase、固定步长、暂停分组、性能预算 | 没有物理固定步、异常隔离、耗时统计、动态优先级 | P2 |
| Resource / AssetLoading | 2.5/5 | 引用计数、异步加载、分组、热更新、预加载 | 缓存策略简单，缺少资源引用关系和异步加载 | P1 |
| Save | 3/5 | Provider、多槽位、迁移、原子写、云存档、快照 | 自动注册生命周期风险，远程/混合存档未实现，缺少 schema | P1 |
| Runtime | 2/5 | Local/Remote/Hybrid 策略、预测、回滚、重放 | 只有 Local 真正可用，Remote/Hybrid 返回未实现 | P0 |
| Network | 1.5/5 | HTTP/WebSocket、重试、超时、认证、断线恢复 | 只有抽象和 Mock，没有真实客户端 | P0 |
| DataAccess | 2/5 | Repository、事务、revision、冲突解决、缓存 | 接口存在，缺少真实实现和与 Runtime/Save 的集成 | P1 |
| Audio | 2.5/5 | cue、bus、混音、池化、淡入淡出、设置保存 | 基础播放可用，缺少音频策略、优先级、实例管理 | P3 |
| Debug | 2.5/5 | stats、console、overlay、命令追踪、profile | 统计较基础，缺少可视化调试面板和事件追踪链 | P2 |
| Localization | 2.5/5 | 多语言加载、参数、fallback、热切换、字体策略 | 基础能力可用，缺少 fallback 链和内容校验 | P3 |
| Algorithm / Pathfinder | 3.5/5 | 可插拔 graph/traversal/heuristic、缓存、异步寻路 | A* 结构合理，但缺少路径缓存、取消、批处理和局部避障 | P2 |

---

## 3. 与市面成熟方案的主要差距

### 3.1 缺少 Framework 级 Command Bus

成熟项目通常会把世界修改统一进入命令管线：

```text
Intent -> Command -> Validate -> Strategy(Local/Remote/Hybrid) -> Apply/Confirm/Rollback -> Event
```

当前项目中，框架已有 `RuntimeService`、`CommandStrategy`、`LocalCommandStrategy`，但真正的 `GameCommandExecutor` 在 Game 层。这样对当前游戏是可工作的，但从框架角度看还不成熟：

- Framework 没有统一命令接口，如 `ICommand`、`ICommandValidator`、`ICommandHandler`。
- Runtime 策略没有接入命令生命周期。
- Prediction / rollback / reconciliation 没有标准上下文。
- 命令执行结果没有统一事件、审计、重放或调试记录。

建议：下一阶段在 Framework 增加轻量 Command Bus，但不要把游戏业务命令放进 Framework。

### 3.2 Remote / Hybrid 仍是概念层

当前 `RuntimeService.get_command_strategy()` 和 `get_save_strategy()` 对 `Remote/Hybrid` 直接返回未实现。这意味着配置里虽然有模式开关，但生产行为只有 Local。

成熟框架通常至少有：

- Remote authority provider
- 本地预测记录
- command sequence id
- server ack / nack
- rollback snapshot
- reconciliation patch
- 断线重连和状态拉取

建议：把 Remote/Hybrid 标记为实验特性，短期内不要让游戏层误以为已经可用；中期补 `RemoteCommandStrategy`、`HybridCommandStrategy` 和基础确认协议。

### 3.3 UI 模块已有骨架，但缺少完整交互系统

这次加入 UI input gate 后，UI 阻挡世界输入的边界更清楚了。对照 RimWorld、Oxygen Not Included、Unity UI Toolkit 或 Unreal UMG，当前仍缺：

- 焦点系统和键盘/手柄导航
- modal stack 和 pointer capture 的统一规则
- ViewModel / Projection / Binding 层
- Tooltip、ContextMenu、DragDrop 标准组件
- Theme / Skin / Style 统一入口
- UI 自动化测试和输入回归测试

当前 `UIPanelDef` 可以描述生命周期和输入阻挡，但还不能描述 UI 的数据依赖、布局策略和交互模型。

建议：短期继续保持轻量，不要过早做完整 UI 框架；优先补 `UIPanel` 的显示状态、焦点、modal、tooltip 和 input gate 测试。

### 3.4 Input 仍是轮询动作服务，不是完整输入系统

`InputService` 的 action context 栈是正确方向，但成熟输入模块通常会覆盖：

- action phase：pressed / held / released / canceled
- pointer event：down / move / up / drag / hover
- rebinding
- 多设备输入：keyboard、mouse、gamepad、touch
- UI 与 gameplay 输入模式切换
- 输入录制和回放

当前 `InputService` 只封装 `InputMap` 的查询，并通过 context / blocker 控制动作是否放行。它足够支撑 MVP，但还不是完整输入系统。

建议：下一步把鼠标拖拽、点击、hover 抽象成 pointer action，不要继续让 GameBootstrap 自己维护复杂输入状态。

### 3.5 Save 自动注册方便，但生命周期风险较高

`ISaveable` 自动注册让早期开发很快，但成熟框架一般会更显式：

- save domain registry
- save schema version
- entity snapshot / diff snapshot
- load ordering
- dependency restore
- corrupted save fallback
- cloud/local conflict policy

当前风险：

- `ISaveable` 的生命周期和注册/注销时机容易与 Godot Node 生命周期错位。
- `load_and_restore()` 只是按 key 分发，没有依赖顺序。
- 缺少 save schema 或字段级迁移说明。
- Remote/Hybrid save strategy 尚未实现。

建议：保留自动注册作为便利层，但为世界/实体/系统存档增加显式 registry 和 restore order。

### 3.6 ResourceService 过于简单

当前资源服务提供缓存和分组释放，但成熟项目常见能力包括：

- async load / threaded load
- preload manifest
- dependency tracking
- reference counting
- scene transition loading screen
- memory budget
- hot reload / asset version

当前 `_cache` 是简单 path -> resource，`MAX_UNCACHED` 固定，分组枚举也偏示例化。对于 MVP 可以接受，但中期会成为场景切换和内容扩展的瓶颈。

建议：先补异步加载和 loading progress，再补资源清单与引用计数。

### 3.7 Network / DataAccess 更像接口草图

`NetworkClient` 只有抽象和 Mock，`DataAccess` 有 Repository / UnitOfWork / Revision，但没有真实实现，也没有接入 Runtime、Command、Save。

成熟项目通常会让这些模块形成闭环：

```text
CommandStrategy -> Repository/Network -> Revision -> ChangeSet -> Save/Cache
```

当前还没有闭环，所以它们暂时不能算生产可用能力。

建议：在做 Remote/Hybrid 前，先定义一条最小闭环：提交命令、返回 revision、应用 patch、本地存快照。

---

## 4. 分模块问题清单

### Application / Installer

优点：

- 三阶段装配清晰：Core -> Engine -> Services。
- 失败时有 `_cleanup_on_fail()`。
- `GameServices` 将 Game 层依赖显式化。

问题：

- `REQUIRED_KEYS` 和 installer 顺序硬编码，模块依赖关系没有声明。
- 失败恢复只清理已 ready 模块，配置中间失败的半初始化对象处理有限。
- 缺少模块装配测试或依赖图校验。

建议：

- 增加 `ModuleDescriptor`：name、dependencies、factory、configure。
- 增加 bootstrap contract tests。
- 给 `_on_post_boot()` 提供更明确的启动阶段上下文。

### UI / Input

优点：

- UI 生命周期和层级清晰。
- 现在已有 `POINTER_ONLY` 输入阻挡模式。
- `InputContext` 栈能表达 UI 或暂停状态下的动作限制。

问题：

- `UIService` 和 `InputService` 通过 callback 连接，缺少可观察性：某个 action 被哪个面板阻挡不易调试。
- `UIPanelDef.GameInputBlockMode` 在 GDScript linter 中跨文件引用不稳定，因此现在 Game 层使用数值常量配置，类型表达力弱。
- Pointer 阻挡只覆盖 action 查询，不覆盖直接调用 Godot `Input` 的代码。需要项目约束和测试兜底。

建议：

- 增加 `InputBlockResult` 或 debug 查询：action、panel、mode、reason。
- 文档明确禁止 Game 层直接使用 `Input.is_*`。
- 为 `POINTER_ONLY` 写一个框架契约测试。

### SceneHost / SceneFactory

优点：

- 世界层和 UI 层挂载点稳定。
- `WorldRoot.ctx` 自动注入，Game 层不需要直接访问 Registry。

问题：

- `replace_world()` 创建新世界后才 `unload_world()`，如果新世界 setup 有副作用，失败恢复会复杂。
- 加载是同步的，没有 loading progress 或取消。
- `_clear_children()` 只是 `queue_free()`，没有等待释放，也没有生命周期事件。

建议：

- 引入 `WorldLoadOperation`：prepare -> unload old -> mount new -> ready。
- 支持 async scene loading。
- 给世界切换加 `_on_world_enter/_on_world_exit` 明确生命周期。

### Runtime / Command

优点：

- Local/Remote/Hybrid 的方向明确。
- `CommandStrategy` 预留了策略替换点。

问题：

- Remote/Hybrid 未实现。
- Framework 没有命令总线，导致 Game 层必须自己组织 command executor。
- 没有 command id、sequence、dedupe、replay。

建议：

- 增加 Framework 级 `CommandBus` 和 `CommandEnvelope`。
- Local 先做完整链路：validate、execute、event、trace。
- 再做 Hybrid：snapshot、predict、confirm、rollback。

### Save

优点：

- Provider 抽象和版本迁移入口已存在。
- `FileSystemService.write_text_atomic()` 为本地存档提供了基础安全性。

问题：

- `SaveService` 只支持 installer 中创建的 Local provider。
- restore 顺序不明确。
- 自动注册 saveable 对复杂世界状态不够可控。
- 版本迁移缺少字段级 schema 和测试样例。

建议：

- 增加 `SaveManifest`：模块、版本、restore_order、dependencies。
- 增加 corrupted save 检测和 backup restore。
- 增加 save migration contract tests。

### Resource / Asset

优点：

- 禁止业务层散落 `load()` 的方向正确。
- 有资源组和 LRU 的最小实现。

问题：

- 分组枚举写死示例关卡，不适合作为框架通用 API。
- 没有异步加载和进度。
- 没有引用计数或资源依赖。

建议：

- 把 `ResourceGroup` 从 enum 改为 String 或 Resource 标签。
- 增加 `load_async()` 和进度查询。
- 增加资源 manifest。

### EventBus

优点：

- token 和 scope 清理机制实用。
- dispatch 中移除监听有 pending remove 保护。

问题：

- 事件名是自由字符串，payload 无约束。
- callback 异常没有隔离。
- 没有优先级、once token 自动释放诊断、事件 trace。

建议：

- 增加事件常量或 EventDef。
- 增加 debug trace：事件名、监听数、耗时。
- dispatch 时保护单个 listener 失败不影响其他 listener。

### Network / DataAccess

优点：

- 抽象方向正确：Request / Response / Repository / UnitOfWork / Revision。

问题：

- 没有真实 HTTP client。
- UnitOfWork 只收集 Dictionary operation，没有类型化 operation。
- Repository 接口没有配套实现和测试。

建议：

- 先实现 Godot `HTTPRequest` adapter。
- 定义最小 `WorldPatch` 和 `Revision` 协议。
- 让 Runtime command strategy 使用 DataAccess，而不是并列存在。

---

## 5. 优先级路线图

### P0：必须先明确的能力边界

1. 明确 Remote/Hybrid 是未完成能力，避免项目误用。
2. 定义 Framework 级 Command Bus 最小接口。
3. 实现真实 NetworkClient 或明确延期。

### P1：支撑当前游戏继续扩展

1. Input pointer action 抽象，减少 GameBootstrap 手写拖拽状态。
2. UI input gate 契约测试和调试输出。
3. SceneHost 世界切换生命周期。
4. Save restore order 和 SaveManifest。
5. Resource async loading。

### P2：提高工程稳定性

1. Installer 依赖图和契约测试。
2. EventBus typed event / trace。
3. Scheduler 耗时统计、异常隔离。
4. Logging 结构化输出和文件写入策略优化。

### P3：体验与工具化

1. UI theme / focus / tooltip / navigation。
2. Debug overlay 和命令追踪面板。
3. Localization fallback 和内容校验。
4. Audio bus、fade、pool、priority。

---

## 6. 建议的下一步

短期不要一次性把框架做“大”。建议只做三条最有收益的链路：

1. **Command Bus 最小闭环**  
   Framework 定义命令 envelope、handler、strategy、trace；Game 只提供具体 command 和 handler。

2. **Input/UI 契约测试**  
   保证所有世界输入都走 `InputService`，UI pointer-only 阻挡不会回归。

3. **Save Manifest + Restore Order**  
   把当前自动注册 saveable 变成可控顺序恢复，为后续复杂世界和 ECS 迁移留空间。

这三条能直接强化当前项目最核心的边界：世界修改、玩家输入、状态持久化。
