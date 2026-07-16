## Revision — 世界状态版本号。每次成功提交变更后递增。
##
## ⚠️ 预留接口：多人/网络模式（Remote / Hybrid Authority）。
## 当前 Local 模式不使用此接口。
##
## 计划用途：
##   - Remote Authority：乐观锁机制，提交时检查版本号匹配
##   - Hybrid Authority：客户端预测版本校验
##
## 注意：此类当前无使用场景，不要实例化。
class_name Revision
extends RefCounted

var value: int = 1
