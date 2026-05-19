## SaveVersionMigrator
## 存档版本迁移器抽象基类。负责将旧版本存档数据迁移到新版本。
## Game 层为每个版本跨度创建具体的 Migrator 子类，注册到 SaveService。
class_name SaveVersionMigrator
extends RefCounted

## 源版本号。此迁移器处理的存档版本。
var from_version: int = 0
## 目标版本号。迁移后的存档版本。
var to_version: int = 0


## 执行迁移。p_data 为旧版本数据，返回迁移后的新版本数据。
## 迁移失败返回 fail，SaveService 将拒绝加载该存档。
func migrate(p_data: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "SaveVersionMigrator")
