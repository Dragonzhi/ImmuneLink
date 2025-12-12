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
	var pipes_data = _generate_pipes()
	var pipe_positions = []
	for pipe in pipes_data:
		pipe_positions.append(Vector2(pipe.position[0], pipe.position[1]))
		
	var level_data = {
		"starting_resources": _generate_starting_resources(),
		"game_time_limit": 300.0, # Placeholder
		"pipes": pipes_data,
		"spawners": _generate_spawners_and_paths(pipe_positions),
		"waves": _generate_waves(),
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
	var total_life_pipes = 2
	var total_supply_pipes = (randi_range(1, 2) * 2) # 生成2或4个资源管道

	# 生成生命管道
	for i in range(total_life_pipes):
		var pipe_data = _generate_unique_position_data(positions)
		pipes.append({
			"name": "random_life_%d" % (i + 1),
			"type": "LIFE",
			"position": [pipe_data.position.x, pipe_data.position.y],
			"direction": pipe_data.direction
		})
		positions.append(pipe_data.position)

	# 生成资源管道
	for i in range(total_supply_pipes):
		var pipe_data = _generate_unique_position_data(positions)
		pipes.append({
			"name": "random_supply_%d" % (i + 1),
			"type": "SUPPLY",
			"position": [pipe_data.position.x, pipe_data.position.y],
			"direction": pipe_data.direction
		})
		positions.append(pipe_data.position)

	print("RandomLevelGenerator: 生成随机管道布局: ", pipes)
	return pipes

# 通用辅助函数：生成一个不与现有位置冲突的、唯一的边缘位置数据
func _generate_unique_position_data(existing_positions: Array) -> Dictionary:
	var unique_data = {}
	var attempts = 0
	while unique_data.is_empty() and attempts < 100: # 安全循环
		var potential_data = _get_random_grid_position_and_direction_on_edge()
		var is_too_close = false
		for pos in existing_positions:
			if pos.distance_to(potential_data.position) < MIN_PIPE_DISTANCE:
				is_too_close = true
				break
		if not is_too_close:
			unique_data = potential_data
		attempts += 1
	
	if unique_data.is_empty():
		printerr("无法生成唯一的实体位置！")
		return _get_random_grid_position_and_direction_on_edge()
		
	return unique_data

# 辅助函数：在屏幕四边之一上获取一个对齐网格的随机位置和朝内的方向，带边缘偏移
func _get_random_grid_position_and_direction_on_edge() -> Dictionary:
	var edge = randi_range(0, 3) # 0: 上, 1: 下, 2: 左, 3: 右
	var pos = Vector2.ZERO
	var dir = "UP"

	# 计算网格边界
	var max_nx = (SCREEN_WIDTH / GRID_CELL_SIZE) - 1
	var max_ny = (SCREEN_HEIGHT / GRID_CELL_SIZE) - 1
	var margin_n = EDGE_MARGIN / GRID_CELL_SIZE # 这是网格单位的“内部”边缘

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


func _generate_spawners_and_paths(existing_entity_positions: Array) -> Array:
	var spawners = []
	var all_positions = existing_entity_positions.duplicate() # 复制一份，不修改原始数组
	var total_spawners = 1
	
	for i in range(total_spawners):
		# 1. 在地图中心区域生成一个唯一的、不重叠的位置
		var spawner_pos = _generate_unique_center_position(all_positions)
		if spawner_pos == Vector2.INF: # 如果找不到位置，则跳过
			printerr("无法为出生点找到一个唯一的位置！")
			continue
			
		# 2. 为这个中心位置的出生点生成一条通往边缘的路径
		var path_points = _generate_path_from_center_to_edge(spawner_pos)
		
		spawners.append({
			"name": "RandomSpawner%02d" % (i + 1),
			"position": [spawner_pos.x, spawner_pos.y],
			"paths": [ path_points ]
		})
		
		all_positions.append(spawner_pos)

	print("RandomLevelGenerator: 生成随机出生点 (居中): ", spawners)
	return spawners

# 辅助函数：在地图中心区域生成一个唯一的、对齐网格的位置
func _generate_unique_center_position(existing_positions: Array) -> Vector2:
	var attempts = 0
	while attempts < 100:
		# 计算中心区域的网格索引范围
		var margin_n = EDGE_MARGIN / GRID_CELL_SIZE
		var max_nx = (SCREEN_WIDTH / GRID_CELL_SIZE) - 1
		var max_ny = (SCREEN_HEIGHT / GRID_CELL_SIZE) - 1
		
		var n_x = randi_range(margin_n, max_nx - margin_n)
		var n_y = randi_range(margin_n, max_ny - margin_n)
		
		var potential_pos = Vector2(GRID_OFFSET + n_x * GRID_CELL_SIZE, GRID_OFFSET + n_y * GRID_CELL_SIZE)
		
		# 检查是否与现有实体太近
		var is_too_close = false
		for pos in existing_positions:
			if pos.distance_to(potential_pos) < MIN_PIPE_DISTANCE:
				is_too_close = true
				break
		
		if not is_too_close:
			return potential_pos # 找到一个有效位置，返回
			
		attempts += 1
	
	return Vector2.INF # 表示找不到合适的位置


# 辅助函数：从中心点生成一条到随机边缘的路径
func _generate_path_from_center_to_edge(start_pos: Vector2) -> Array:
	var path = [[start_pos.x, start_pos.y]]
	
	# 随机选择一个目标边缘
	var edge = randi_range(0, 3) # 0: 上, 1: 下, 2: 左, 3: 右
	var end_pos = Vector2.ZERO
	
	var margin_n = EDGE_MARGIN / GRID_CELL_SIZE
	var max_nx = (SCREEN_WIDTH / GRID_CELL_SIZE) - 1
	var max_ny = (SCREEN_HEIGHT / GRID_CELL_SIZE) - 1
	
	var end_nx = 0
	var end_ny = 0

	match edge:
		0: # 上
			end_nx = randi_range(margin_n, max_nx - margin_n)
			end_ny = randi_range(-EDGE_OFFSET_RANGE_N, margin_n - 1)
		1: # 下
			end_nx = randi_range(margin_n, max_nx - margin_n)
			end_ny = randi_range(max_ny - margin_n + 1, max_ny + EDGE_OFFSET_RANGE_N)
		2: # 左
			end_nx = randi_range(-EDGE_OFFSET_RANGE_N, margin_n - 1)
			end_ny = randi_range(margin_n, max_ny - margin_n)
		3: # 右
			end_nx = randi_range(max_nx - margin_n + 1, max_nx + EDGE_OFFSET_RANGE_N)
			end_ny = randi_range(margin_n, max_ny - margin_n)
	
	end_pos.x = GRID_OFFSET + end_nx * GRID_CELL_SIZE
	end_pos.y = GRID_OFFSET + end_ny * GRID_CELL_SIZE
	
	# 生成一个中间拐点，使路径呈 "L" 形
	var turn_pos = Vector2(start_pos.x, end_pos.y) # 默认先垂直移动，再水平移动
	if randi() % 2 == 0: # 随机切换移动顺序
		turn_pos = Vector2(end_pos.x, start_pos.y)

	path.append([turn_pos.x, turn_pos.y])
	path.append([end_pos.x, end_pos.y])
	
	return path


func _generate_simple_path(start_pos: Vector2) -> Array:
	var path = [[start_pos.x, start_pos.y]]
	var current_pos = start_pos
	
	# 计算网格边界和中心
	var max_nx = (SCREEN_WIDTH / GRID_CELL_SIZE) - 1
	var max_ny = (SCREEN_HEIGHT / GRID_CELL_SIZE) - 1
	var center_nx = max_nx / 2
	var center_ny = max_ny / 2

	# 第一步：向屏幕内部移动
	var inward_n_dist = randi_range(4, 7) # 向内移动4-7个格子
	var move_dir = Vector2.ZERO
	if current_pos.x < SCREEN_WIDTH / 2: 
		move_dir.x = 1 
	else: 
		move_dir.x = -1
	if current_pos.y < SCREEN_HEIGHT / 2: 
		move_dir.y = 1 
	else: 
		move_dir.y = -1
	
	var first_turn_pos = current_pos + Vector2(move_dir.x, 0) * inward_n_dist * GRID_CELL_SIZE
	if randi() % 2 == 0: # 随机先横向或纵向移动
		first_turn_pos = current_pos + Vector2(move_dir.x, 0) * inward_n_dist * GRID_CELL_SIZE
	else:
		first_turn_pos = current_pos + Vector2(0, move_dir.y) * inward_n_dist * GRID_CELL_SIZE
	
	# 确保不出界
	first_turn_pos.x = clamp(first_turn_pos.x, GRID_OFFSET, SCREEN_WIDTH - GRID_OFFSET)
	first_turn_pos.y = clamp(first_turn_pos.y, GRID_OFFSET, SCREEN_HEIGHT - GRID_OFFSET)
	path.append([first_turn_pos.x, first_turn_pos.y])
	
	# 第二步：向屏幕中心移动
	var center_pos_x = GRID_OFFSET + randi_range(center_nx - 2, center_nx + 2) * GRID_CELL_SIZE
	var center_pos_y = GRID_OFFSET + randi_range(center_ny - 2, center_ny + 2) * GRID_CELL_SIZE
	
	path.append([center_pos_x, center_pos_y])
	
	return path

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
	var enemy_types = []
	var path = "res://scenes/enemies/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# 确保是 .tscn 文件，并且不是目录，也不是基础敌人场景
			if not dir.current_is_dir() and file_name.ends_with(".tscn") and "Base" not in file_name:
				var type_name = file_name.get_basename() # 例如 "VirusEnemy.tscn" -> "VirusEnemy"
				enemy_types.append(type_name)
			file_name = dir.get_next()
	else:
		printerr("无法打开敌人目录: ", path)
		
	return enemy_types
