extends Resource
class_name LevelConfig

@export var level_name: String = "未命名关卡"
@export var starting_resources: int = 100
@export var level_duration: float = 300.0
@export var tutorial_sequence_path: String = "" # 教程序列资源的路径 (res://...)
@export var starting_wave_index: int = 0 # 波次管理器可以从这个索引开始

func _to_string() -> String:
	return "关卡配置: %s" % level_name
