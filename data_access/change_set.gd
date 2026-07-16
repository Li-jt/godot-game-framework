## ChangeSet — 一组世界状态变更 + 期望版本号。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口。
##
## 计划用途：
##   - Remote Authority：检查 expected_revision 防止并发写入覆盖
##   - Hybrid Authority：客户端预测变更集校验
##
## 注意：此类当前无使用场景，不要实例化。
class_name ChangeSet
extends RefCounted

## 变更操作列表。每项为 Dictionary，由 Game 层定义结构。
## 示例：{"type": "place_building", "id": "b_001", "x": 10, "y": 5}
var operations: Array = []

## 提交时期望的世界版本号。不匹配则拒绝提交（并发冲突）。
var expected_revision: int = 0
