## InputGestureProfile — 手势配置（v4.0）。
## 定义单击/双击手势的参数，由 InputActionDef 持有，GestureEngine 读取。
class_name InputGestureProfile
extends RefCounted

## 是否启用手势
var enable_click_gesture: bool = false
## 单击触发的动作 ID
var single_action_id: String = ""
## 双击触发的动作 ID
var double_action_id: String = ""
## 双击检测窗口（毫秒）
var double_click_window_ms: int = 300
## 是否要求两次点击目标相同
var require_same_target: bool = true
## 拖拽取消阈值（像素，超过此距离取消 click 候选）
var drag_cancel_px: float = 8.0
