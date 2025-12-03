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

# --- Public API for Upgrades ---

## 处理来自UI的升级请求
func request_upgrade(upgrade: Upgrade, target_bridge: Bridge):
	if not upgrade or not is_instance_valid(target_bridge):
		return
		
	print("GameManager 正在处理对桥梁 %s 的升级请求: %s" % [target_bridge.grid_pos, upgrade.upgrade_name])
	
	if spend_resource_value(upgrade.cost):
		print("资源足够，正在应用升级...")
		target_bridge.attempt_upgrade(upgrade)
		# 升级后通常需要关闭菜单并取消选择
		deselect_all_turrets()
	else:
		print("资源不足，升级失败！")
		# 在这里可以触发一个UI提示，比如播放一个“资源不足”的音效

# --- Selection Management ---
@onready var ui_manager: Node = get_node("/root/Main/UIManager")
var _selected_turret: Node = null

func select_turret(turret: Node):
	# 如果我们再次点击同一个炮塔，则取消选择
	if _selected_turret == turret:
		deselect_all_turrets()
		return

	# 如果之前有选中的炮塔，先取消它的选中状态
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("deselect"):
			_selected_turret.deselect()
		if ui_manager and ui_manager.has_method("close_upgrade_menu"):
			ui_manager.close_upgrade_menu()

	# 选中新的炮塔
	_selected_turret = turret
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("select"):
			_selected_turret.select()
		
		# 检查新选中的炮塔是否有可用的升级
		if _selected_turret.has_method("get_available_upgrades"):
			var upgrades = _selected_turret.get_available_upgrades()
			# 如果有，则通知UI管理器打开菜单并传递升级列表
			if not upgrades.is_empty():
				if ui_manager and ui_manager.has_method("open_upgrade_menu"):
					ui_manager.open_upgrade_menu(upgrades, _selected_turret)
			else:
				print("此桥段当前没有可用的升级。")

func deselect_all_turrets():
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("deselect"):
			_selected_turret.deselect()
	
	if ui_manager and ui_manager.has_method("close_upgrade_menu"):
		ui_manager.close_upgrade_menu()
		
	_selected_turret = null
