extends Node

# --- 随机生成参数 ---
const MIN_STARTING_RESOURCES = 250   # 最小初始资源
const MAX_STARTING_RESOURCES = 300   # 最大初始资源

const SCREEN_WIDTH = 384             # 屏幕宽度
const SCREEN_HEIGHT = 216            # 屏幕高度
const EDGE_MARGIN = 32               # 边缘间距，用于在生成时避免过于靠近角落
const MIN_PIPE_DISTANCE = 48         # 管道/实体间的最小距离
const GRID_CELL_SIZE = 16            # 网格单元尺寸
const GRID_OFFSET = 8                # 网格偏移量
const EDGE_OFFSET_RANGE_N = 1        # 边缘偏移的网格单元数 (+/- N个格子)

const MIN_SPAWNERS = 1               # 最小出生点数量
const MAX_SPAWNERS = 1               # 最大出生点数量 (已设为1)

const MIN_WAVES = 3                  # 最少波数
const MAX_WAVES = 5                  # 最多波数
const MIN_ENEMIES_PER_WAVE = 5       # 每波最少敌人数量 (基础值)
const MAX_ENEMIES_PER_WAVE = 15      # 每波最多敌人数量 (基础值)
const MIN_SPAWN_INTERVAL = 0.5       # 最小出怪间隔
const MAX_SPAWN_INTERVAL = 2.0       # 最大出怪间隔


# Main public function to be called to generate random level data
func generate_random_level_data() -> Dictionary:
	# 调整顺序：先生成波次，以确定需要多少条路径
	var waves_data = _generate_waves()
	
	var pipes_data = _generate_pipes()
	var pipe_positions = []
	for pipe in pipes_data:
		pipe_positions.append(Vector2(pipe.position[0], pipe.position[1]))
		
	var level_data = {
		"starting_resources": _generate_starting_resources(),
		"game_time_limit": 300.0, # Placeholder
		"pipes": pipes_data,
		"spawners": _generate_spawners_and_paths(pipe_positions, waves_data.size()),
		"waves": waves_data,
		"initial_delay": 5.0 # Placeholder
	}
	print("随机关卡数据已生成: ", level_data)
	return level_data

# --- 私有占位函数 ---

func _generate_starting_resources() -> int:
	var random_resources = randi_range(MIN_STARTING_RESOURCES, MAX_STARTING_RESOURCES)
	print("RandomLevelGenerator: 生成随机初始资源: ", random_resources)
	return random_resources

func _generate_pipes() -> Array:
	var pipes = []
	var positions = []
	
	var corner_config = randi() % 2
	var life_is_first_corner = randi() % 2 == 0
	
	var corner1_edges = [2, 0] if corner_config == 0 else [3, 0] # 左/上 或 右/上
	var corner2_edges = [3, 1] if corner_config == 0 else [2, 1] # 右/下 或 左/下

	var life_edges = corner1_edges if life_is_first_corner else corner2_edges
	var supply_edges = corner2_edges if life_is_first_corner else corner1_edges
	
	print("RandomLevelGenerator: 生成邻边布局 (八字)")

	# 1. 生成生命管道 (总是一对)
	var life_pipe_1_data = _generate_unique_position_on_edge(life_edges[0], positions)
	positions.append(life_pipe_1_data.position)
	pipes.append({"name": "random_life_A", "type": "LIFE", "position": [life_pipe_1_data.position.x, life_pipe_1_data.position.y], "direction": life_pipe_1_data.direction})
	
	var life_pipe_2_data = _generate_unique_position_on_edge(life_edges[1], positions)
	positions.append(life_pipe_2_data.position)
	pipes.append({"name": "random_life_B", "type": "LIFE", "position": [life_pipe_2_data.position.x, life_pipe_2_data.position.y], "direction": life_pipe_2_data.direction})

	# 2. 生成资源管道 (1或2对)
	var num_supply_pairs = randi_range(1, 2)
	for i in range(num_supply_pairs):
		var suffix = char(ord("A") + i) # A, B, C...
		var supply_pipe_1_data = _generate_unique_position_on_edge(supply_edges[0], positions)
		positions.append(supply_pipe_1_data.position)
		pipes.append({"name": "random_supply_%s_1" % suffix, "type": "SUPPLY", "position": [supply_pipe_1_data.position.x, supply_pipe_1_data.position.y], "direction": supply_pipe_1_data.direction})

		var supply_pipe_2_data = _generate_unique_position_on_edge(supply_edges[1], positions)
		positions.append(supply_pipe_2_data.position)
		pipes.append({"name": "random_supply_%s_2" % suffix, "type": "SUPPLY", "position": [supply_pipe_2_data.position.x, supply_pipe_2_data.position.y], "direction": supply_pipe_2_data.direction})

	print("RandomLevelGenerator: 生成分区管道布局: ", pipes)
	return pipes

# 新的辅助函数：在 *指定* 边缘生成一个唯一的位置
func _generate_unique_position_on_edge(edge_id: int, existing_positions: Array) -> Dictionary:
	var unique_data = {}
	var attempts = 0
	while unique_data.is_empty() and attempts < 100:
		var potential_data = _get_random_grid_position_on_edge(edge_id)
		var is_too_close = false
		for pos in existing_positions:
			if pos.distance_to(potential_data.position) < MIN_PIPE_DISTANCE:
				is_too_close = true
				break
		if not is_too_close:
			unique_data = potential_data
		attempts += 1
	
	if unique_data.is_empty():
		printerr("无法在指定边缘 %d 上生成唯一的实体位置！" % edge_id)
		return _get_random_grid_position_on_edge(edge_id)
		
	return unique_data

# 修改旧函数，使其可以接受一个指定的边缘ID
func _get_random_grid_position_on_edge(forced_edge: int = -1) -> Dictionary:
	var edge = forced_edge if forced_edge != -1 else randi_range(0, 3) # 0:上, 1:下, 2:左, 3:右
	var pos = Vector2.ZERO
	var dir = "UP"

	# 计算网格边界
	var max_nx = (SCREEN_WIDTH / GRID_CELL_SIZE) - 1
	var max_ny = (SCREEN_HEIGHT / GRID_CELL_SIZE) - 1
	var margin_n = EDGE_MARGIN / GRID_CELL_SIZE

	var n_x = 0
	var n_y = 0

	match edge:
		0: # 上
			n_x = randi_range(margin_n, max_nx - margin_n)
			n_y = randi_range(-EDGE_OFFSET_RANGE_N, margin_n - 1) 
			dir = "DOWN"
		1: # 下
			n_x = randi_range(margin_n, max_nx - margin_n)
			n_y = randi_range(max_ny - margin_n + 1, max_ny + EDGE_OFFSET_RANGE_N)
			dir = "UP"
		2: # 左
			n_x = randi_range(-EDGE_OFFSET_RANGE_N, margin_n - 1)
			n_y = randi_range(margin_n, max_ny - margin_n)
			dir = "RIGHT"
		3: # 右
			n_x = randi_range(max_nx - margin_n + 1, max_nx + EDGE_OFFSET_RANGE_N)
			n_y = randi_range(margin_n, max_ny - margin_n)
			dir = "LEFT"
	
	pos.x = GRID_OFFSET + n_x * GRID_CELL_SIZE
	pos.y = GRID_OFFSET + n_y * GRID_CELL_SIZE
			
	return {"position": pos, "direction": dir}


func _generate_spawners_and_paths(existing_entity_positions: Array, num_paths: int) -> Array:
	var spawners = []
	var all_positions = existing_entity_positions.duplicate()
	var total_spawners = 1
	
	for i in range(total_spawners):
		var spawner_pos = _generate_unique_center_position(all_positions)
		if spawner_pos == Vector2.INF:
			printerr("无法为出生点找到一个唯一的位置！")
			continue
			
		var all_paths = []
		for j in range(num_paths):
			# 将所有实体的位置（管道+出生点）传递给路径生成器，以避开它们
			all_paths.append(_generate_complex_loop_path(spawner_pos, all_positions))
		
		spawners.append({
			"name": "RandomSpawner%02d" % (i + 1),
			"position": [spawner_pos.x, spawner_pos.y],
			"paths": all_paths
		})
		
		all_positions.append(spawner_pos)

	print("RandomLevelGenerator: 生成随机出生点 (居中): ", spawners)
	return spawners

# 辅助函数：在地图中心区域生成一个唯一的、对齐网格的位置
func _generate_unique_center_position(existing_positions: Array, clearance: float = MIN_PIPE_DISTANCE) -> Vector2:
	var attempts = 0
	while attempts < 100:
		var margin_n = EDGE_MARGIN / GRID_CELL_SIZE
		var max_nx = (SCREEN_WIDTH / GRID_CELL_SIZE) - 1
		var max_ny = (SCREEN_HEIGHT / GRID_CELL_SIZE) - 1
		
		var n_x = randi_range(margin_n, max_nx - margin_n)
		var n_y = randi_range(margin_n, max_ny - margin_n)
		
		var potential_pos = Vector2(GRID_OFFSET + n_x * GRID_CELL_SIZE, GRID_OFFSET + n_y * GRID_CELL_SIZE)
		
		var is_too_close = false
		for pos in existing_positions:
			if pos.distance_to(potential_pos) < clearance:
				is_too_close = true
				break
		
		if not is_too_close:
			return potential_pos
			
		attempts += 1
	
	return Vector2.INF

# 辅助函数：生成一条复杂的环路路径
func _generate_complex_loop_path(start_pos: Vector2, obstacles: Array) -> Array:
	var waypoints = [start_pos]
	var num_intermediate_waypoints = 3 # 生成3个中间航点，总共5个点
	
	for i in range(num_intermediate_waypoints):
		# 为航点也设置一个最小间距，避免路径点过于密集
		var waypoint = _generate_unique_center_position(obstacles + waypoints, 32.0)
		if waypoint != Vector2.INF:
			waypoints.append(waypoint)
	
	# 如果中间航点少于3个（因为找不到位置），就补充一些简单的点
	while waypoints.size() < num_intermediate_waypoints + 1:
		waypoints.append(Vector2(waypoints.back().x + randi_range(-3, 3) * GRID_CELL_SIZE, waypoints.back().y + randi_range(-3, 3) * GRID_CELL_SIZE))

	waypoints.append(start_pos) # 添加最后一个点，形成环路

	# 将 Vector2 数组转换为 [x, y] 数组
	var path_data = []
	for p in waypoints:
		path_data.append([p.x, p.y])
		
	return path_data


func _generate_waves() -> Array:
	var waves = []
	var available_enemies = _get_available_enemy_types()
	
	if available_enemies.is_empty():
		printerr("RandomLevelGenerator: 在 res://scenes/enemies/ 中未找到任何敌人场景！")
		return []
		
	var total_waves = randi_range(MIN_WAVES, MAX_WAVES)
	
	for i in range(total_waves):
		var wave_data = {}
		
		# 难度递增：波数越靠后，敌人越多
		var min_enemies = MIN_ENEMIES_PER_WAVE + i * 2 # 每波至少增加2个敌人
		var max_enemies = MAX_ENEMIES_PER_WAVE + i * 3 # 每波敌人上限增加3个
		
		wave_data["default_enemy_count"] = randi_range(min_enemies, max_enemies)
		wave_data["default_spawn_interval"] = randf_range(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)
		wave_data["post_wave_delay"] = randf_range(3.0, 7.0) # 波次之间的随机延迟
		
		# 为当前波次随机选择敌人类型
		var enemies_in_wave = []
		var enemy_types_in_this_wave_count = randi_range(1, max(1, available_enemies.size() / 2)) # 最多使用一半的可用敌人类型
		var available_enemies_copy = available_enemies.duplicate()
		available_enemies_copy.shuffle()
		
		for j in range(enemy_types_in_this_wave_count):
			if available_enemies_copy.is_empty(): break
			var enemy_type = available_enemies_copy.pop_front()
			enemies_in_wave.append({
				"type": enemy_type,
				"weight": randi_range(1, 5) # 随机权重
			})
		
		wave_data["enemies"] = enemies_in_wave
		waves.append(wave_data)
		
	print("RandomLevelGenerator: 生成随机波次: ", waves)
	return waves

# 辅助函数：扫描敌人目录以获取所有可用的敌人类型名称
func _get_available_enemy_types() -> Array:
	# DirAccess 在导出版本中（尤其是在Web和移动端）不稳定，因此我们硬编码敌人列表
	# 这样可以确保在所有平台上都能正确生成敌人波次
	var enemy_types = [
		"CD4TEnemy",
		"DCEnemy",
		"GermEnemy",
		"MacrophageEnemy",
		"VirusEnemy"
	]
	return enemy_types
