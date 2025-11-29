extends Control

@onready var repair_label: Label = $HBoxContainer/RepairLabel
@onready var resource_label: Label = $HBoxContainer/ResourceLabel

func _ready() -> void:
	# Connect to the GameManager signals
	GameManager.repair_value_changed.connect(_on_repair_value_changed)
	GameManager.resource_value_changed.connect(_on_resource_value_changed)
	
	# Initialize labels with current values using the new getters
	_on_repair_value_changed(GameManager.get_repair_value())
	_on_resource_value_changed(GameManager.get_resource_value())

func _on_repair_value_changed(new_value: float):
	repair_label.text = "修复值: %d / 100" % int(new_value)

func _on_resource_value_changed(new_value: float):
	resource_label.text = "资源: %d" % int(new_value)
