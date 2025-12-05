extends Control

@onready var repair_label: Label = $HBoxContainer/RepairLabel
@onready var resource_label: Label = $HBoxContainer/ResourceLabel
@onready var time_label: Label = $PanelContainer/TimeLabel

func _ready() -> void:
	# Connect to the GameManager signals
	GameManager.repair_value_changed.connect(_on_repair_value_changed)
	GameManager.resource_value_changed.connect(_on_resource_value_changed)
	GameManager.time_remaining_changed.connect(_on_time_remaining_changed) # 新增：连接时间信号
	
	# Initialize labels with current values
	_on_repair_value_changed(GameManager.get_repair_value())
	_on_resource_value_changed(GameManager.get_resource_value())
	_on_time_remaining_changed(GameManager.get_time_remaining()) # 新增：初始化时间显示

func _on_repair_value_changed(new_value: float):
	repair_label.text = "修复值: %d / 100" % int(new_value)

func _on_resource_value_changed(new_value: float):
	resource_label.text = "资源: %d" % int(new_value)

# 新增：处理时间更新的函数
func _on_time_remaining_changed(new_time: float):
	if not time_label: return
	
	var minutes = int(new_time) / 60
	var seconds = int(new_time) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds] # 格式化为 MM:SS
