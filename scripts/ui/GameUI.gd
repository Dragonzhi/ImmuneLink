extends Control

@onready var repair_label: Label = $HBoxContainer/RepairLabel
@onready var resource_label: Label = $HBoxContainer/ResourceLabel
@onready var time_label: Label = $PanelContainer/TimeLabel
@onready var feedback_label: Label = $FeedbackLabel
@onready var feedback_timer: Timer = $FeedbackTimer


func _ready() -> void:
	# Connect to the GameManager signals
	GameManager.repair_value_changed.connect(_on_repair_value_changed)
	GameManager.resource_value_changed.connect(_on_resource_value_changed)
	GameManager.time_remaining_changed.connect(_on_time_remaining_changed)
	
	# Connect to the UIManager for feedback messages
	var ui_manager = get_node("/root/Main/UIManager")
	if ui_manager and ui_manager.has_signal("feedback_requested"):
		ui_manager.feedback_requested.connect(show_feedback)
	
	# Connect timer timeout
	feedback_timer.timeout.connect(_on_feedback_timer_timeout)
	
	# Initialize labels with current values
	_on_repair_value_changed(GameManager.get_repair_value())
	_on_resource_value_changed(GameManager.get_resource_value())
	_on_time_remaining_changed(GameManager.get_time_remaining())


func show_feedback(message: String, duration: float = 2.0) -> void:
	feedback_label.text = message
	feedback_label.show()
	feedback_timer.start(duration)


func _on_feedback_timer_timeout() -> void:
	feedback_label.hide()


func _on_repair_value_changed(new_value: float):
	repair_label.text = "修复值: %d / 100" % int(new_value)

func _on_resource_value_changed(new_value: float):
	resource_label.text = "资源: %d" % int(new_value)

func _on_time_remaining_changed(new_time: float):
	if not time_label: return
	
	var minutes = int(new_time) / 60
	var seconds = int(new_time) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
