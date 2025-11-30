extends Node

signal repair_value_changed(new_value: float)
signal resource_value_changed(new_value: float)

@export var initial_resources: float = 200.0

var _repair_value: float = 0.0:
	set(value):
		_repair_value = value
		emit_signal("repair_value_changed", _repair_value)

var _resource_value: float = 0.0:
	set(value):
		_resource_value = value
		emit_signal("resource_value_changed", _resource_value)

func _ready() -> void:
	self._resource_value = initial_resources
	self._repair_value = 0.0

# --- Public Methods ---

func add_repair_value(amount: float):
	self._repair_value = min(_repair_value + amount, 100.0)
	if _repair_value >= 100.0:
		print("胜利条件已达成！")
		# get_tree().change_scene_to_file("res://win_screen.tscn")

func add_resource_value(amount: float):
	self._resource_value += amount

func spend_resource_value(amount: float) -> bool:
	if _resource_value >= amount:
		self._resource_value -= amount
		return true
	else:
		print("资源不足！需要: %s, 当前拥有: %s" % [amount, _resource_value])
		return false

# --- Getters for UI ---
func get_repair_value() -> float:
	return _repair_value

func get_resource_value() -> float:
	return _resource_value

# --- Selection Management ---
@onready var ui_manager: Node = get_node("/root/Main/UIManager")
var _selected_turret: Node = null

func select_turret(turret: Node):
	# If we click the same turret again, deselect it.
	if _selected_turret == turret:
		deselect_all_turrets()
		return

	# If a different turret was selected, deselect it first.
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("deselect"):
			_selected_turret.deselect()
		if ui_manager and ui_manager.has_method("close_upgrade_menu"):
			ui_manager.close_upgrade_menu()

	# Select the new turret.
	_selected_turret = turret
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("select"):
			_selected_turret.select()
		if ui_manager and ui_manager.has_method("open_upgrade_menu"):
			ui_manager.open_upgrade_menu(_selected_turret)

func deselect_all_turrets():
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("deselect"):
			_selected_turret.deselect()
	
	if ui_manager and ui_manager.has_method("close_upgrade_menu"):
		ui_manager.close_upgrade_menu()
		
	_selected_turret = null
