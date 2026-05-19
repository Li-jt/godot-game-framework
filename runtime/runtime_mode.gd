## RuntimeMode
## 运行时模式枚举。
class_name RuntimeMode
extends RefCounted

enum Mode {
	LOCAL,   # 本地即权威，直接读写，不依赖网络
	REMOTE,  # 远程即权威，操作依赖远程确认
	HYBRID,  # 本地预测 + 远程确认，失败回滚
}

static func from_string(p_text: String) -> Mode:
	match p_text.to_lower():
		"local": return Mode.LOCAL
		"remote": return Mode.REMOTE
		"hybrid": return Mode.HYBRID
		_: return Mode.LOCAL
