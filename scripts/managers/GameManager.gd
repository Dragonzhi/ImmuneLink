extends Node

signal repair_value_changed(new_value: float)
signal resource_value_changed(new_value: float)

var _repair_value: float = 0.0:
	set(value):
		_repair_value = value
		emit_signal("repair_value_changed", _repair_value)

var _resource_value: float = 0.0:
	set(value):
		_resource_value = value
		emit_signal("resource_value_changed", _resource_value)

func _ready() -> void:
	# 连接场景切换信号，以便在新关卡加载时进行初始化
	get_tree().scene_changed.connect(_on_scene_changed)
	# 这段代码应当写在自动加载里。
	# 初始启动时，也尝试进行一次初始化
	_on_scene_changed()


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

# --- Signal Handlers ---

# 🚀 改进 3: 将函数签名改为不带参数
func _on_scene_changed():
	# 在这里获取新的场景节点
	var new_scene = get_tree().current_scene
	
	print("【Scene Changed Signal】场景已切换，新场景: " + str(new_scene.get_path()))

	# 现在 new_scene 不会是 null，因为它是在信号触发后获取的
	if not is_instance_valid(new_scene): return
	
	# 尝试在心场景中寻找 LevelConfig 节点
	var level_config = new_scene.find_child("LevelConfig", true, false)
	if level_config:
		# 如果找到了，说明这是一个关卡场景，用它的配置来初始化资源
		self._resource_value = level_config.starting_resources
		self._repair_value = 0.0 # 同时重置其他关卡状态
	# else:
		# 如果没找到（比如在主菜单），保持资源不变


# --- Public API for Upgrades ---

## 处理来自UI的升级请求
func request_upgrade(upgrade: Upgrade, target_bridge: Bridge):
	if not upgrade or not is_instance_valid(target_bridge):
		return
		
	if spend_resource_value(upgrade.cost):
		target_bridge.attempt_upgrade(upgrade)
		# 升级后通常需要关闭菜单并取消选择
		deselect_all_turrets()

# --- Selection Management ---
var _selected_turret: Node = null

func select_turret(turret: Node):
	var ui_manager = get_node_or_null("/root/Main/UIManager") # 即用即取
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

func deselect_all_turrets():
	var ui_manager = get_node_or_null("/root/Main/UIManager") # 即用即取
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("deselect"):
			_selected_turret.deselect()
	
	if ui_manager and ui_manager.has_method("close_upgrade_menu"):
		ui_manager.close_upgrade_menu()
		
	_selected_turret = null
