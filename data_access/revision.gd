## Revision
## 世界状态版本号。每次成功提交变更后递增。
## 用于乐观锁：提交时检查 expected_revision 是否匹配当前值。
class_name Revision
extends RefCounted

var value: int = 1
