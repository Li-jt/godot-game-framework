## ChangeSet
## 一组世界状态变更 + 期望版本号。
## 提交到 Repository 时检查 expected_revision，防止并发写入覆盖。
class_name ChangeSet
extends RefCounted

## 变更操作列表。每项为 Dictionary，由 Game 层定义结构。
## 示例：{"type": "place_building", "id": "b_001", "x": 10, "y": 5}
var operations: Array = []

## 提交时期望的世界版本号。不匹配则拒绝提交（并发冲突）。
var expected_revision: int = 0
