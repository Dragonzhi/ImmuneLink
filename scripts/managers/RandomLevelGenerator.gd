extends Node

const MIN_STARTING_RESOURCES = 250
const MAX_STARTING_RESOURCES = 300

const SCREEN_WIDTH = 384
const SCREEN_HEIGHT = 216
const EDGE_MARGIN = 32
const MIN_PIPE_DISTANCE = 48 # 管道间的最小距离
const GRID_CELL_SIZE = 16
const GRID_OFFSET = 8
const EDGE_OFFSET_RANGE_N = 1 # +/- 1 个网格单元 (16px)

# Main public function to be called to generate random level data
func generate_random_level_data() -> Dictionary:
	var level_data = {
		"starting_resources": _generate_starting_resources(),
		"game_time_limit": 300.0, # Placeholder
		"pipes": _generate_pipes(),
		"spawners": _generate_spawners_and_paths(),
		"waves": _generate_waves(),
		"initial_delay": 5.0 # Placeholder
	}
	print("随机关卡数据已生成 (占位): ", level_data)
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
		var pipe_data = _generate_unique_pipe_data(positions)
		pipes.append({
			"name": "random_life_%d" % (i + 1),
			"type": "LIFE",
			"position": [pipe_data.position.x, pipe_data.position.y],
			"direction": pipe_data.direction
		})
		positions.append(pipe_data.position)

	# 生成资源管道
	for i in range(total_supply_pipes):
		var pipe_data = _generate_unique_pipe_data(positions)
		pipes.append({
			"name": "random_supply_%d" % (i + 1),
			"type": "SUPPLY",
			"position": [pipe_data.position.x, pipe_data.position.y],
			"direction": pipe_data.direction
		})
		positions.append(pipe_data.position)

	print("RandomLevelGenerator: 生成随机管道布局: ", pipes)
	return pipes

# 辅助函数：生成一个不与现有位置冲突的、唯一的管道数据
func _generate_unique_pipe_data(existing_positions: Array) -> Dictionary:
	var unique_data = {}
	var attempts = 0
	while unique_data.is_empty() and attempts < 100: # 安全循环，防止死循环
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
		# 如果尝试多次后仍然找不到唯一位置，则返回一个随机位置作为后备
		printerr("无法生成唯一的管道位置！")
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
			n_x = randi_range(margin_n, max_nx - margin_n) # X仍保持在内边缘范围内
			# Y可以从-1（一个单元格向外）到 margin_n-1（边缘的内侧）
			n_y = randi_range(-EDGE_OFFSET_RANGE_N, margin_n - 1) 
			dir = "DOWN"
		1: # 下
			n_x = randi_range(margin_n, max_nx - margin_n)
			# Y可以从 max_ny - margin_n + 1（边缘的内侧）到 max_ny + 1（一个单元格向外）
			n_y = randi_range(max_ny - margin_n + 1, max_ny + EDGE_OFFSET_RANGE_N)
			dir = "UP"
		2: # 左
			# X可以从-1到 margin_n-1
			n_x = randi_range(-EDGE_OFFSET_RANGE_N, margin_n - 1)
			n_y = randi_range(margin_n, max_ny - margin_n) # Y仍保持在内边缘范围内
			dir = "RIGHT"
		3: # 右
			# X可以从 max_nx - margin_n + 1 到 max_nx + 1
			n_x = randi_range(max_nx - margin_n + 1, max_nx + EDGE_OFFSET_RANGE_N)
			n_y = randi_range(margin_n, max_ny - margin_n)
			dir = "LEFT"
	
	pos.x = GRID_OFFSET + n_x * GRID_CELL_SIZE
	pos.y = GRID_OFFSET + n_y * GRID_CELL_SIZE
			
	return {"position": pos, "direction": dir}

func _generate_spawners_and_paths() -> Array:
	# TODO: 实现随机出生点和路径逻辑
	print("RandomLevelGenerator: 生成固定的出生点和路径 (占位)")
	var spawners = [
		{
			"name": "RandomSpawner01",
			"position": [200, 48],
			"paths": [
				[ [200, 48], [168, 48], [-32, 128], [0, 128] ] # 一条简单的路径
			]
		}
	]
	return spawners

func _generate_waves() -> Array:
	# TODO: 实现随机波次逻辑
	print("RandomLevelGenerator: 生成固定的敌人波次 (占位)")
	var waves = [
		{
			"default_enemy_count": 5,
			"default_spawn_interval": 1.5,
			"post_wave_delay": 5.0,
			"enemies": [
				{"type": "VirusEnemy", "weight": 1}
			]
		}
	]
	return waves
