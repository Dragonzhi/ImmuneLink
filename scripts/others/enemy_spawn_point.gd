extends Node2D

signal enemy_spawned # Emitted when an enemy is spawned.
signal spawner_finished(spawner) # Emitted when this spawner has met its wave quota.

const EnemySpawnInfo = preload("res://scripts/others/EnemySpawnInfo.gd")

@export var enemy_list: Array[EnemySpawnInfo]
@export var delete_enemy_at_path_end: bool = true

var grid_manager: GridManager
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var spawn_timer: Timer = $SpawnTimer
@onready var path_visualizer: Line2D = $PathVisualizer

var tween: Tween
var _paths: Array[Path2D]
var current_path_index: int = 0

# --- Wave Control Variables ---
var _enemies_to_spawn_this_wave: int = 0
var _enemies_spawned_this_wave: int = 0

func _ready() -> void:
	DebugManager.register_category("EnemySpawnPoint", false)
	# 使用 call_deferred 确保此方法在 LevelLoader 可能已经添加完子路径后执行。
	call_deferred("update_paths_from_children")

	path_visualizer.visible = false
	path_visualizer.modulate.a = 0.0
	call_deferred("_register_occupied_cells")

## (新) 公共方法，用于从子节点刷新内部的路径列表。
## LevelLoader 在动态添加 Path2D 子节点后也应调用此方法以确保路径被识别。
func update_paths_from_children():
	_paths.clear()
	for child in get_children():
		if child is Path2D:
			_paths.append(child)
	
	if _paths.is_empty():
		printerr("敌人生成点 '%s' 错误: 在子节点中未找到任何 Path2D！" % self.name)
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		return
	
	# 对路径按名称排序，确保多路径时顺序一致
	_paths.sort_custom(func(a, b): return a.name < b.name)
	
	current_path_index = clamp(current_path_index, 0, _paths.size() - 1)
	_update_path_visualizer()
	DebugManager.dprint("EnemySpawnPoint", "生成器 %s: 已从子节点更新路径列表，共找到 %d 条路径。" % [self.name, _paths.size()])


# --- Public Methods for WaveManager Control ---

## 由 WaveManager 调用，开始生成这一波的敌人
func start_spawning(new_enemy_list: Array[EnemySpawnInfo], interval: float, count: int):
	DebugManager.dprint("EnemySpawnPoint", "生成器 %s: 开始生成，间隔：%s，数量：%s。" % [self.name, interval, count])
	if new_enemy_list.is_empty() or interval <= 0 or count <= 0:
		return
		
	self.enemy_list = new_enemy_list
	_enemies_to_spawn_this_wave = count
	_enemies_spawned_this_wave = 0
	
	# Ensure the signal is connected only once
	if spawn_timer.timeout.is_connected(spawn_enemy):
		spawn_timer.timeout.disconnect(spawn_enemy)
	spawn_timer.timeout.connect(spawn_enemy)
		
	spawn_timer.wait_time = interval
	spawn_timer.start()
	DebugManager.dprint("EnemySpawnPoint", "生成器 %s 已开始生成。配额：%s。" % [self.name, _enemies_to_spawn_this_wave])

## 停止生成
func stop_spawning():
	if not spawn_timer.is_stopped():
		spawn_timer.stop()
		DebugManager.dprint("EnemySpawnPoint", "生成器 %s: 计时器已停止。" % self.name)
		# print("Spawner %s stopped spawning." % self.name) # 这行信息重复了

## (新) 由 WaveManager 调用，根据索引设置当前使用的路径
func set_active_path_by_index(index: int):
	if _paths.is_empty() or index < 0 or index >= _paths.size():
		printerr("为 %s 设置路径失败: 索引 %d 无效。" % [self.name, index])
		return
	
	if current_path_index == index: return # 路径未改变，无需操作

	current_path_index = index
	
	# 播放路径切换特效并更新可视化
	if PathFXManager:
		PathFXManager.play_path_animation(_paths[current_path_index])
	_update_path_visualizer()
	DebugManager.dprint("EnemySpawnPoint", "生成器 %s 的路径已切换到: %s (索引: %d)" % [self.name, _paths[current_path_index].name, index])

## (新) 获取该出生点总共有几条路径
func get_path_count() -> int:
	return _paths.size()

# --- Internal Functions ---
func spawn_enemy():
	DebugManager.dprint("EnemySpawnPoint", "生成器 %s: spawn_enemy 被调用。已生成：%s，配额：%s。" % [self.name, _enemies_spawned_this_wave, _enemies_to_spawn_this_wave])
	if enemy_list.is_empty():
		return
	
	var active_path = _paths[current_path_index]
	if not is_instance_valid(active_path) or not active_path.curve:
		printerr("敌人生成点错误: 当前活跃路径无效！")
		return
	
	var chosen_enemy_info = _get_random_enemy()
	if not chosen_enemy_info or not chosen_enemy_info.enemy_scene:
		printerr("敌人生成点错误: 选中的敌人信息无效或场景未设置！")
		return
		
	var enemy_instance: BaseEnemy = chosen_enemy_info.enemy_scene.instantiate()
	var main_node = get_tree().get_root().get_node("Main")
	if not main_node:
		printerr("敌人生成点 %s 无法找到 Main 节点！" % self.name)
		return

	# 将敌人添加到主场景，而不是路径节点
	main_node.add_child(enemy_instance)
	
	# 设置敌人的初始位置为路径的第一个点
	if not active_path.curve.get_baked_points().is_empty():
		enemy_instance.global_position = active_path.to_global(active_path.curve.get_baked_points()[0])
	else:
		enemy_instance.global_position = self.global_position # 备用方案
	
	# 将路径信息传递给敌人
	enemy_instance.set_path(active_path)
	# 将生成点自身的引用传递给敌人，以便后续进行路线切换检查
	enemy_instance.spawner = self
	
	_enemies_spawned_this_wave += 1
	emit_signal("enemy_spawned")
	
	# 在生成完敌人后，再次检查是否已达到或超过配额
	# 确保信号只在最后一个敌人生成后发出
	if _enemies_spawned_this_wave >= _enemies_to_spawn_this_wave:
		DebugManager.dprint("EnemySpawnPoint", "生成器 %s: 配额已满足。发出 'spawner_finished' 信号。" % self.name)
		stop_spawning()
		emit_signal("spawner_finished", self)

func get_active_path() -> Path2D:
	if not _paths.is_empty():
		return _paths[current_path_index]
	return null

func _get_random_enemy() -> EnemySpawnInfo:
	var total_weight = 0
	for spawn_info in enemy_list:
		total_weight += spawn_info.weight
	
	if total_weight <= 0:
		return null

	var random_value = randi_range(1, total_weight)
	
	for spawn_info in enemy_list:
		random_value -= spawn_info.weight
		if random_value <= 0:
			return spawn_info
			
	return null

func _register_occupied_cells():
	grid_manager = get_node("/root/GridManager")
	if not grid_manager:
		printerr("敌人生成点错误: 未找到GridManager！")
		return
	
	if not collision_shape:
		return

	var shape_transform = collision_shape.global_transform
	var shape_rect = collision_shape.shape.get_rect()
	var global_aabb = shape_transform * shape_rect
	var top_left_world = global_aabb.position
	var bottom_right_world = global_aabb.position + global_aabb.size
	var start_grid_pos = grid_manager.world_to_grid(top_left_world)
	var end_grid_pos = grid_manager.world_to_grid(bottom_right_world)
	var min_x = min(start_grid_pos.x, end_grid_pos.x)
	var max_x = max(start_grid_pos.x, end_grid_pos.x)
	var min_y = min(start_grid_pos.y, end_grid_pos.y)
	var max_y = max(start_grid_pos.y, end_grid_pos.y)
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var grid_pos = Vector2i(x, y)
			if grid_manager.is_within_bounds(grid_pos):
				grid_manager.set_grid_occupied(grid_pos, self)

func _update_path_visualizer():
	if path_visualizer and not _paths.is_empty() and _paths[current_path_index].curve:
		path_visualizer.points = _paths[current_path_index].curve.get_baked_points()
	else:
		path_visualizer.points = []

func _on_area_2d_mouse_entered() -> void:
	path_visualizer.visible = true
	
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(path_visualizer, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

func _on_area_2d_mouse_exited() -> void:
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.tween_property(path_visualizer, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_hide_visualizer)

func _hide_visualizer():
	path_visualizer.visible = false
