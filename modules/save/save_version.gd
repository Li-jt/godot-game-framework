## GF_SaveVersion
## 存档版本常量。当前存档结构版本号。
## 每次 SaveData 结构发生变化时递增此值，并创建对应的 GF_SaveVersionMigrator。
class_name GF_SaveVersion
extends RefCounted

## 当前存档结构版本。增量升级时递增（1→2→3...）。
const CURRENT: int = 1
