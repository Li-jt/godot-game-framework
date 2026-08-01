# 框架版本升级指南

## 当前版本

**0.3.0** — 框架主要功能已稳定，ECS、Save、Input、UI、Audio 等核心模块完整实现。Remote/Hybrid 运行时模式为预留阶段。

## 版本号规则

遵循语义化版本（SemVer）：

```
主版本号.次版本号.修订号
  MAJOR . MINOR . PATCH
```

| 变更类型 | 版本号变化 | 说明 |
|---------|-----------|------|
| 新增功能（向后兼容） | MINOR +1 | 新增 class_name、新增方法、新增模块 |
| Bug 修复（向后兼容） | PATCH +1 | 修复框架 bug，不改变 API |
| Breaking Change | MAJOR +1 | 删除/重命名 class_name、修改公共 API 签名、删除公开方法 |

## Breaking Changes 记录

暂无。当前版本 0.3.0 是第一个文档化版本。

> 未来版本中的 Breaking Changes 将在此处记录，每项包含：变更描述、影响范围、迁移指南。

## 升级步骤

### 通过 Git Submodule 升级

```bash
# 进入游戏项目的 framework 子模块目录
cd addons/godot-game-framework

# 拉取最新版本
git fetch origin
git checkout v0.3.0  # 或 main 分支最新

# 返回游戏项目
cd ../..

# 提交子模块更新
git add addons/godot-game-framework
git commit -m "chore: 升级 framework 到 v0.3.0"
```

### 通过复制升级

```bash
# 删除旧版本
rm -rf addons/godot-game-framework/

# 复制新版本
cp -r /path/to/godot-game-framework/ addons/godot-game-framework/

# 排除不需要的目录
rm -rf addons/godot-game-framework/tests/
rm -rf addons/godot-game-framework/docs/
rm -rf addons/godot-game-framework/.git/
```

### 升级后检查清单

1. **运行游戏**: 确认游戏能正常启动
2. **检查配置**: `app_config.json` 是否有新增的必需字段
3. **检查存档**: 旧存档是否能正常加载（版本迁移链是否完整）
4. **检查 API 变更**: 查看框架的 CHANGELOG，确认公共 API 无 Breaking Change
5. **运行测试**: 如果有自己的测试，全部运行一遍

## 存档兼容性

### 版本迁移机制

存档系统通过 `GF_SaveVersionMigrator` 实现自动版本迁移。每次存档格式变化时需要：

1. 递增 `GF_SaveVersion.CURRENT`
2. 创建新的 `GF_SaveVersionMigrator` 子类（如 `V1ToV2Migrator`）
3. 在 SaveService 注册迁移器

```gdscript
# 注册迁移器（在 _on_post_boot 中）
save_service.register_migrator(V1ToV2Migrator.new())
save_service.register_migrator(V2ToV3Migrator.new())
```

### 向后兼容保证

- **同 MAJOR 版本内的存档兼容**：旧版本存档可通过迁移链自动升级
- **跨 MAJOR 版本的存档**：不保证兼容，需要提供完整的迁移链
- **存档版本高于当前版本**：返回 `ERR_MIGRATION` 错误，提示用户升级游戏

## 已知兼容性问题

### Godot 4.6 → 4.7

框架目前针对 Godot 4.7 开发。在 Godot 4.6 上使用需注意：

1. **WorkerThreadPool API**: 4.7 中有细微改进，ThreadingService 在 4.6 上的行为可能需要验证
2. **GDScript 类型系统**: 4.7 对静态类型检查更严格，部分 `Variant` 标注可能需要调整
3. **推荐使用 Godot 4.7**: 框架开发和测试均在 4.7 上进行

### 从更早版本升级

如果从框架 0.2.x 或更早版本升级：

1. 检查 `class_name` 前缀是否从无前缀变为 `GF_` 前缀
2. 检查 `OperationResult` 错误码是否有新增/变更
3. 检查 `ModuleLifecycle` 生命周期钩子是否有变化

## 框架依赖

| 依赖 | 最低版本 | 说明 |
|------|---------|------|
| Godot Engine | 4.7 | 推荐使用最新 4.7.x |
| 无外部插件依赖 | - | 框架不依赖任何第三方 Godot 插件 |

---

## CHANGELOG 摘要

### v0.3.0 (当前)

- ECS: SparseSet 和 Archetype 双存储实现
- ECS: CommandBuffer 延迟批量写入
- ECS: Snapshot 完整序列化和回放
- Save: 多注册路径（collect_from_node / child_entering_tree / register_saveable）
- Save: 恢复优先级控制（restore_priority）
- Input: 上下文栈权限控制
- Input: 按键重绑定（RebindService）
- UI: 三层拖拽系统（L1 协议层 / L2 便利层 / L3 游戏层）
- UI: 面板输入阻挡策略
- Threading: 线程任务服务（优先级队列/超时/重试/取消/统计）
- Application: 10 个生命周期 Hook
- Application: ServiceRegistry 优先级覆盖和按 owner 批量注销
- 整体: `class_name` 统一 `GF_` 前缀
- 整体: 所有公共 API 返回 `OperationResult`
