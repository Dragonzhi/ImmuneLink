# LevelLoader.gd
extends Node

class_name LevelLoader

const ENEMY_SPAWN_POINT_SCENE = preload("res://scenes/others/enemy_spawn_point.tscn")
const PIPE_SCENE = preload("res://scenes/pipes/Pipe.tscn")
const WAVE_CLASS = preload("res://scripts/managers/Wave.gd")
const ENEMY_SPAWN_INFO_CLASS = preload("res://scripts/others/EnemySpawnInfo.gd")

# 接收关卡文件名，智能查找路径并加载
func load_level_from_json(level_filename: String, scene_root: Node2D) -> Dictionary:
	var final_level_path: String
	
	# 1. 智能查找关卡文件路径
	var user_base_dir = "user://ImmuneLink/"
	var user_levels_dir = user_base_dir.path_join("levels/")
	var user_path = user_levels_dir.path_join(level_filename)

	# 确保 user://ImmuneLink/levels/ 目录存在 (尤其是在第一次运行时)
	var dir_access = DirAccess.open("user://")
	if not dir_access.dir_exists("ImmuneLink"):
		var err_create_base = dir_access.make_dir("ImmuneLink")
		if err_create_base != OK:
			printerr("LevelLoader 错误: 无法创建 user://ImmuneLink/ 目录！错误码: %s" % err_create_base)
			return {}
	if not dir_access.dir_exists("ImmuneLink/levels"):
		var err_create_levels = dir_access.make_dir("ImmuneLink/levels")
		if err_create_levels != OK:
			printerr("LevelLoader 错误: 无法创建 user://ImmuneLink/levels/ 目录！错误码: %s" % err_create_levels)
			return {}

	if FileAccess.file_exists(user_path):
		print("LevelLoader: 发现用户自定义关卡，从 user:// 加载: ", user_path)
		final_level_path = user_path
	else:
		var res_path = "res://levels/data/".path_join(level_filename)
		if FileAccess.file_exists(res_path):
			print("LevelLoader: 加载内置关卡，从 res:// 加载: ", res_path)
			final_level_path = res_path
		else:
			printerr("LevelLoader 错误: 在 user://levels/ 和 res://levels/data/ 中都未找到关卡文件: ", level_filename)
			return {}
			
	# 2. 加载和解析JSON文件
	var level_data = _parse_json(final_level_path)
	if level_data.is_empty():
		return {}
	
	# 3. 加载和配置场景中的节点 (Pipes, Spawners)
	_load_pipes(level_data.get("pipes", []), scene_root)
	_load_spawners(level_data.get("spawners", []), scene_root)

	# 4. 加载和配置 WaveManager 的数据
	var waves = _load_waves(level_data.get("waves", []))
	var initial_delay = level_data.get("initial_delay", 5.0)
	
	var wave_manager = scene_root.find_child("WaveManager", true, false)
	if wave_manager:
		wave_manager.waves = waves
		wave_manager.initial_delay = initial_delay
		# Spawners可能已更新, 重新获取
		var spawners_in_scene: Array[Node] = []
		for node in scene_root.get_tree().get_nodes_in_group("spawners"):
			if scene_root.is_ancestor_of(node):
				spawners_in_scene.append(node)
		wave_manager.spawners = spawners_in_scene
	else:
		printerr("LevelLoader 错误: 场景中未找到 WaveManager 节点！")

	# 5. 返回关卡数据字典，由 MainController 负责配置 GameManager
	return level_data

func _parse_json(level_path: String) -> Dictionary:
	var file = FileAccess.open(level_path, FileAccess.READ)
	if not file:
		printerr("打开关卡文件失败: ", level_path)
		return {}

	var content = file.get_as_text()
	file.close()

	var json_result = JSON.parse_string(content)
	if json_result == null:
		printerr("从关卡文件解析JSON失败: ", level_path)
		return {}
	
	return json_result as Dictionary

func _load_pipes(pipes_data: Array, scene_root: Node):
	var pipes_container_red = scene_root.get_node("BackGround/Pipes/Red")
	var pipes_container_blue = scene_root.get_node("BackGround/Pipes/Blue")
	
	if not pipes_container_red or not pipes_container_blue:
		printerr("场景中未找到Pipes容器节点 (Red/Blue)!")
		return

	# 收集场景中现有的Pipes
	var existing_pipes = {}
	for child in pipes_container_red.get_children():
		existing_pipes[child.name] = child
	for child in pipes_container_blue.get_children():
		existing_pipes[child.name] = child
	
	# 遍历JSON数据，更新或创建Pipe
	for pipe_info in pipes_data:
		var pipe_name = pipe_info.get("name")
		if pipe_name == null: continue

		var pipe_node: Node2D = existing_pipes.get(pipe_name)

		if pipe_node:
			# 如果找到同名Pipe，则更新它
			existing_pipes.erase(pipe_name) # 从“待处理”列表中移除
		else:
			# 如果没找到，则创建新的Pipe
			pipe_node = PIPE_SCENE.instantiate()
			pipe_node.name = pipe_name
			if pipe_info.get("type") == "LIFE":
				pipes_container_red.add_child(pipe_node)
			else: # SUPPLY or other types
				pipes_container_blue.add_child(pipe_node)
		
		# 配置Pipe属性
		var pos_array = pipe_info.get("position", [0, 0])
		pipe_node.global_position = Vector2(pos_array[0], pos_array[1])
		
		var type_str = pipe_info.get("type", "LIFE")
		if type_str in Pipe.PipeType:
			pipe_node.pipe_type = Pipe.PipeType[type_str]
		
		var direction_str = pipe_info.get("direction", "UP")
		if direction_str in Pipe.Direction:
			pipe_node.direction_enum = Pipe.Direction[direction_str]
		else:
			# 如果JSON中的值不匹配，默认设置为 UP
			pipe_node.direction_enum = Pipe.Direction.UP

		# 根据direction_enum设置节点的旋转
		match pipe_node.direction_enum:
			Pipe.Direction.UP:
				pipe_node.rotation_degrees = 0
			Pipe.Direction.RIGHT:
				pipe_node.rotation_degrees = 90
			Pipe.Direction.DOWN:
				pipe_node.rotation_degrees = 180
			Pipe.Direction.LEFT:
				pipe_node.rotation_degrees = 270

	# 删除JSON中没有定义的、多余的预设Pipe
	for pipe_name in existing_pipes:
		existing_pipes[pipe_name].queue_free()


func _load_spawners(spawners_data: Array, scene_root: Node):
	var spawners_container = scene_root.get_node("BackGround/EnemySpawns")
	if not spawners_container:
		printerr("场景中未找到 EnemySpawns 容器节点!")
		return

	var preset_spawner = spawners_container.find_child("EnemySpawnPoint01", false)
	
	# 先清除掉除了预设Spawner之外的所有其他Spawner
	for spawner in spawners_container.get_children():
		if spawner != preset_spawner:
			spawner.queue_free()
	
	if spawners_data.is_empty():
		# 如果JSON中没有spawner，则也删除预设的
		if preset_spawner:
			preset_spawner.queue_free()
		return

	# 使用第一个JSON条目配置预设的Spawner
	var first_spawner_info = spawners_data[0]
	if not preset_spawner:
		# 如果预设的不知为何不存在，就创建一个
		preset_spawner = ENEMY_SPAWN_POINT_SCENE.instantiate()
		preset_spawner.name = "EnemySpawnPoint01"
		spawners_container.add_child(preset_spawner)
	_configure_spawner(preset_spawner, first_spawner_info)

	# 如果JSON中有更多Spawner，则创建新的
	if spawners_data.size() > 1:
		for i in range(1, spawners_data.size()):
			var spawner_info = spawners_data[i]
			var new_spawner = ENEMY_SPAWN_POINT_SCENE.instantiate()
			new_spawner.name = "EnemySpawnPoint%02d" % (i + 1)
			spawners_container.add_child(new_spawner)
			_configure_spawner(new_spawner, spawner_info)

func _configure_spawner(spawner_node: Node, spawner_info: Dictionary):
	# 位置
	var pos_array = spawner_info.get("position", [0, 0])
	var spawner_pos = Vector2(pos_array[0], pos_array[1])
	spawner_node.global_position = spawner_pos

	# 清除现有路径
	for child in spawner_node.get_children():
		if child is Path2D:
			child.queue_free()
	
	# 添加新路径
	var paths_data = spawner_info.get("paths", [])
	for i in range(paths_data.size()):
		var path_data = paths_data[i]
		if not path_data.is_empty():
			var path2d = Path2D.new()
			path2d.name = "Path%02d" % (i + 1)
			var curve = Curve2D.new()
			for point_array in path_data:
				var world_point = Vector2(point_array[0], point_array[1])
				var local_point = world_point - spawner_pos
				curve.add_point(local_point)
			path2d.curve = curve
			spawner_node.add_child(path2d)

	# 通知 spawner 节点从其子节点更新其内部路径列表
	if spawner_node.has_method("update_paths_from_children"):
		# 使用 call_deferred 确保在节点完全准备好后执行，避免潜在的时序问题
		spawner_node.call_deferred("update_paths_from_children")
	else:
		printerr("LevelLoader 警告: 节点 %s 上没有找到 update_paths_from_children 方法。" % spawner_node.name)

func _load_waves(waves_data: Array) -> Array[WAVE_CLASS]:
	var loaded_waves: Array[WAVE_CLASS] = []
	for wave_data_entry in waves_data:
		var new_wave = WAVE_CLASS.new()
		new_wave.default_enemy_count = wave_data_entry.get("default_enemy_count", 0)
		new_wave.default_spawn_interval = wave_data_entry.get("default_spawn_interval", 1.0)
		new_wave.post_wave_delay = wave_data_entry.get("post_wave_delay", 5.0)

		var loaded_enemy_spawn_infos: Array[ENEMY_SPAWN_INFO_CLASS] = []
		var enemies_data = wave_data_entry.get("enemies", [])
		for enemy_info_entry in enemies_data:
			var new_enemy_spawn_info = ENEMY_SPAWN_INFO_CLASS.new()
			var enemy_type = enemy_info_entry.get("type", "")
			if not enemy_type.is_empty():
				var enemy_scene_path = "res://scenes/enemies/" + enemy_type + ".tscn"
				if ResourceLoader.exists(enemy_scene_path):
					new_enemy_spawn_info.enemy_scene = load(enemy_scene_path)
				else:
					printerr("未找到敌人场景: ", enemy_scene_path)
			new_enemy_spawn_info.weight = enemy_info_entry.get("weight", 1) 
			loaded_enemy_spawn_infos.append(new_enemy_spawn_info)
		
		new_wave.default_spawn_infos = loaded_enemy_spawn_infos
		loaded_waves.append(new_wave)
	return loaded_waves
