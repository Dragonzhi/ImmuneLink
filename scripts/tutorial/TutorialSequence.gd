extends Resource
class_name TutorialSequence

@export var sequence_name: String = "未命名教程序列"
@export var steps: Array[TutorialStep]

func _to_string() -> String:
	return "教程序列: %s (%d 步骤)" % [sequence_name, steps.size()]
