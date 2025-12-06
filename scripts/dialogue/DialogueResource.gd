# DialogueResource.gd
class_name DialogueResource
extends Resource

## 对话数据资源，用于存储一段完整的对话。
## 可以在Godot编辑器中作为.tres文件创建和编辑。

# 导出一个字典数组，每本字典代表一句对话。
# 字典结构:
# {
#   "name": "角色名",
#   "text": "这是对话的具体内容。",
#   "portrait": "res://path/to/portrait.png", (可选)
#   "focus_target_path": NodePath("path/to/node_to_focus") (可选)
# }
@export var dialogue_lines: Array[Dictionary] = []
