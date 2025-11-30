extends Node2D

signal enemy_spawned # Emitted when an enemy is spawned.
signal spawner_finished(spawner) # Emitted when this spawner has met its wave quota.

const EnemySpawnInfo = preload("res://scripts/others/EnemySpawnInfo.gd")

@export var enemy_list: Array[EnemySpawnInfo]
@export var path_switch_interval: float = 30.0
@export var delete_enemy_at_path_end: bool = true

var grid_manager: GridManager
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var spawn_timer: Timer = $SpawnTimer
@onready var path_visualizer: Line2D = $PathVisualizer
@onready var path_switch_timer: Timer = $PathSwitchTimer

var tween: Tween
@export var _paths: Array[Path2D]
var current_path_index: int = 0

# --- Wave Control Variables ---
var _enemies_to_spawn_this_wave: int = 0
var _enemies_spawned_this_wave: int = 0

func _ready() -> void:
	if _paths.is_empty():
		printerr("敌人生成点错误: 未找到任何Path2D子节点！")
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		return
	
	current_path_index = clamp(current_path_index, 0, _paths.size() - 1)
	
	if _paths.size() > 1 and path_switch_timer:
		path_switch_timer.wait_time = path_switch_interval
		path_switch_timer.timeout.connect(_on_path_switch_timer_timeout)
		path_switch_timer.start()

	_update_path_visualizer()
	path_visualizer.visible = false
	path_visualizer.modulate.a = 0.0
	call_deferred("_register_occupied_cells")

# --- Public Methods for WaveManager Control ---
func start_spawning(new_enemy_list: Array[EnemySpawnInfo], interval: float, count: int):
	if new_enemy_list.is_empty() or interval <= 0 or count <= 0:
		return
		
	self.enemy_list = new_enemy_list
	_enemies_to_spawn_this_wave = count
	_enemies_spawned_this_wave = 0
	
	if not spawn_timer.timeout.is_connected(spawn_enemy):
		spawn_timer.timeout.connect(spawn_enemy)
		
	spawn_timer.wait_time = interval
	spawn_timer.start()
	print("Spawner %s started spawning. Quota: %s" % [self.name, _enemies_to_spawn_this_wave])

func stop_spawning():
	if not spawn_timer.is_stopped():
		spawn_timer.stop()
		print("Spawner %s stopped spawning." % self.name)

# --- Internal Functions ---
func spawn_enemy():
	if _enemies_spawned_this_wave >= _enemies_to_spawn_this_wave:
		stop_spawning()
		emit_signal("spawner_finished", self)
		return

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
	enemy_instance.should_delete_at_end = delete_enemy_at_path_end
	enemy_instance.spawner = self # Pass a reference of the spawner to the enemy
	active_path.add_child(enemy_instance)
	
	_enemies_spawned_this_wave += 1
	emit_signal("enemy_spawned")
	
	if _enemies_spawned_this_wave >= _enemies_to_spawn_this_wave:
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
	grid_manager = get_node("/root/Main/GridManager")
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

func _on_path_switch_timer_timeout():
	if _paths.size() < 2: return
	current_path_index = (current_path_index + 1) % _paths.size()
	_update_path_visualizer()
	print("路径已切换到: ", _paths[current_path_index].name)

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
