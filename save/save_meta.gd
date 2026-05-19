## SaveMeta
## 存档元数据。持久化时随 SaveData 一起写入，加载时先读取以判断兼容性。
class_name SaveMeta
extends RefCounted

var slot_id: int = 0
var save_time: String = ""        # 保存时间 "YYYY-MM-DD HH:MM:SS"
var save_version: int = 1         # 存档结构版本
var game_version: String = ""     # 游戏版本号
var play_time_seconds: float = 0.0
var summary: String = ""          # 摘要，如 "第3年 春季"
