extends Node

signal repair_value_changed(new_value: float)
signal resource_value_changed(new_value: float)
signal time_remaining_changed(new_time: float)
signal nk_samples_changed(new_count: int) # 新增：NK样本数量变化信号
signal upgrade_menu_opened(bridge: Bridge) # 新增：当升级菜单打开时发出信号

var _pending_level_config: LevelConfig = null # 存储下个关卡要使用的配置
var _current_active_level_config: LevelConfig = null

var wave_manager : WaveManager

var _repair_value: float = 0.0:
	set(value):
		_repair_value = value
		emit_signal("repair_value_changed", _repair_value)

var _resource_value: float = 0.0:
	set(value):
		_resource_value = value
		emit_signal("resource_value_changed", _resource_value)

var _nk_cell_samples: int = 0:
	set(value):
		_nk_cell_samples = value
		emit_signal("nk_samples_changed", _nk_cell_samples)

var _current_base_health: float = 100.0 # 假设基地生命值
var _time_remaining: float = 0.0:
	set(value):
		_time_remaining = value
		emit_signal("time_remaining_changed", _time_remaining)

var _is_game_over: bool = false

@onready var game_timer: Timer = $GameTimer

func _ready() -> void:
	# 连接自身信号
	get_tree().scene_changed.connect(_on_scene_changed)
	game_timer.timeout.connect(_on_game_timer_timeout)
	
	# DebugManager 注册
	DebugManager.register_category("GameManager", true) # Enable GameManager debug output

	# 初始化
	_on_scene_changed()

# --- Public Methods ---

## 设置下一个关卡要使用的配置
func set_next_level_config(config: LevelConfig):
	_pending_level_config = config
	DebugManager.dprint("GameManager", "已设置下一个关卡配置: %s" % config.level_name)

func add_repair_value(amount: float):
	if _is_game_over: return
	self._repair_value = min(_repair_value + amount, 100.0)
	if _repair_value >= 100.0:
		_handle_victory()

func add_resource_value(amount: float):
	self._resource_value += amount

func spend_resource_value(amount: float) -> bool:
	if _resource_value >= amount:
		self._resource_value -= amount
		return true
	else:
		return false

func add_nk_cell_sample(amount: int):
	self._nk_cell_samples += amount

func spend_nk_cell_sample(amount: int) -> bool:
	if _nk_cell_samples >= amount:
		self._nk_cell_samples -= amount
		return true
	else:
		return false

func take_base_damage(amount: float):
	if _is_game_over: return
	_current_base_health -= amount
	if _current_base_health <= 0:
		_current_base_health = 0
		_handle_defeat("基地被摧毁")

# --- Getters for UI ---
func get_repair_value() -> float:
	return _repair_value

func get_resource_value() -> float:
	return _resource_value

func get_nk_cell_samples() -> int:
	return _nk_cell_samples

func get_time_remaining() -> float:
	return _time_remaining

func is_game_over() -> bool:
	return _is_game_over


# --- Signal Handlers ---

func _on_scene_changed():
	if not is_instance_valid(get_tree().current_scene): return
	
	if _pending_level_config: # 使用 pending 配置
		DebugManager.dprint("GameManager", "正在初始化新关卡: %s。" % _pending_level_config.level_name)

		if ConnectionManager:
			ConnectionManager.reset()
		
		# --- 初始化新关卡状态，从 LevelConfig 读取 ---
		self._resource_value = _pending_level_config.starting_resources
		self._nk_cell_samples = 0
		self._repair_value = 0.0
		self._current_base_health = 100.0 # 可改为从LevelConfig读取
		self._time_remaining = _pending_level_config.level_duration
		self._is_game_over = false
		
		game_timer.wait_time = 1.0
		game_timer.start()

		# --- 使用关卡配置的序列启动教程 ---
		if not _pending_level_config.tutorial_sequence_path.is_empty():
			var tutorial_seq_res = load(_pending_level_config.tutorial_sequence_path)
			if tutorial_seq_res is TutorialSequence:
				if TutorialManager:
					# 获取 WaveManager 实例
					var wave_manager_instance = get_node_or_null("/root/Main/WaveManager")
					if wave_manager_instance:
						TutorialManager.start_tutorial_with_sequence(tutorial_seq_res, wave_manager_instance)
					else:
						printerr("GameManager: 无法找到 WaveManager 节点，无法启动教程！")
				else:
					printerr("GameManager: TutorialManager Autoload未找到！")
			else:
				printerr("GameManager: 加载教程序列失败，路径无效或资源类型不匹配: %s" % _pending_level_config.tutorial_sequence_path)
		else:
			DebugManager.dprint("GameManager", "当前关卡没有配置教程序列。")
		# ----------------------------------------------------
		_current_active_level_config = _pending_level_config
		_pending_level_config = null # 使用后重置，避免影响后续关卡加载

	else: # 如果没有 pending 配置，则视为非关卡场景或默认情况
		DebugManager.dprint("GameManager", "未设置待定关卡配置。非关卡场景或默认初始化。")
		_current_active_level_config = null 
		game_timer.stop()

func _on_game_timer_timeout():
	if _is_game_over: return
	
	self._time_remaining -= 1.0
	if _time_remaining <= 0:
		self._time_remaining = 0
		_handle_defeat("时间耗尽")

# --- Private Victory/Defeat Logic ---

func _handle_victory():
	_start_game_over_sequence(true, "修复完成，模拟成功！")

func _handle_defeat(reason: String):
	_start_game_over_sequence(false, "失败：%s" % reason)

func _start_game_over_sequence(is_victory: bool, message: String):
	if _is_game_over: return
	_is_game_over = true
	
	game_timer.stop()
	
	# 尝试获取WaveManager并停止它
	var wave_manager_node = get_node_or_null("/root/Main/WaveManager")
	if wave_manager_node and wave_manager_node.has_method("stop_wave_system"):
		wave_manager_node.stop_wave_system()

	# 显示横幅
	var ui_manager = get_node_or_null("/root/Main/UIManager")
	if ui_manager and ui_manager.has_method("show_game_over_banner"):
		ui_manager.show_game_over_banner(message)
	
	# 暂停游戏
	get_tree().paused = true
	
	# 创建一个不受暂停影响的Timer
	var timer = Timer.new()
	timer.wait_time = 3.0 # 3秒延迟
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS # 关键：使其在暂停时也能处理
	add_child(timer)
	timer.start()
	timer.timeout.connect(func(): _on_game_over_timer_timeout(is_victory, timer))


@warning_ignore("unused_parameter")
func _on_game_over_timer_timeout(is_victory: bool, timer: Timer):
	# 在切换场景前必须取消暂停
	get_tree().paused = false
	
	# 准备要传递的数据
	@warning_ignore("narrowing_conversion")
	var final_score:int = _resource_value + _repair_value # 简单计算一个分数
	var time_spent = _current_active_level_config.level_duration - _time_remaining
	@warning_ignore("integer_division")
	var minutes:int = int(time_spent) / 60
	var seconds:int = int(time_spent) % 60
	
	SceneManager.scene_data = {
		"score": final_score,
		"time": "%02d:%02d" % [minutes, seconds]
	}
	
	# 切换到结束场景
	SceneManager.change_scene_to_file("res://scenes/ui/screens/EndScreen.tscn")
	
	# 清理Timer
	if is_instance_valid(timer):
		timer.queue_free()



# --- Public API for Upgrades (No changes needed below) ---

func request_upgrade(upgrade: Upgrade, bridge: Bridge):
	"""
	处理来自UI的升级请求。
	检查资源，如果足够则应用升级。
	"""
	if not is_instance_valid(upgrade) or not is_instance_valid(bridge):
		printerr("GameManager: 无效的升级或桥梁实例。")
		return

	if spend_resource_value(upgrade.cost):
		print("GameManager: 资源充足，应用升级 %s 到 %s" % [upgrade.upgrade_name, bridge.name])
		bridge.attempt_upgrade(upgrade)
	else:
		print("GameManager: 资源不足，无法应用升级 %s" % upgrade.upgrade_name)
		# 未来可以在此添加UI提示，例如播放一个“失败”音效或显示一条消息


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
					# --- 新增：打开升级菜单后发出信号 ---
					if _selected_turret is Bridge: # 仅在打开桥梁的菜单时发出
						DebugManager.dprint("GameManager", "Emitting upgrade_menu_opened for bridge: %s" % _selected_turret.name)
						emit_signal("upgrade_menu_opened", _selected_turret)
					# --------------------------------------------------

func deselect_all_turrets():
	var ui_manager = get_node_or_null("/root/Main/UIManager") # 即用即取
	if is_instance_valid(_selected_turret):
		if _selected_turret.has_method("deselect"):
			_selected_turret.deselect()
	
	if ui_manager and ui_manager.has_method("close_upgrade_menu"):
		ui_manager.close_upgrade_menu()
		
	_selected_turret = null

# --- Debug Toggle ---
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"): # 可以通过项目设置修改为其他键，例如"ui_select" for F1
		print("--- Toggling Debug Categories ---")
		var categories = DebugManager.get_all_categories()
		for category in categories:
			DebugManager.toggle_category(category)
			var status = "ENABLED" if DebugManager.is_category_enabled(category) else "DISABLED"
			print("Category '%s' is now %s" % [category, status])
		print("---------------------------------")
