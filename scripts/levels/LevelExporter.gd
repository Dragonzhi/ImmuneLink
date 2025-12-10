@tool
extends Node

## Level Exporter Tool
##
## 使用方法:
## 1. 将此脚本附加到关卡场景中任意一个节点上 (推荐创建一个专门的 LevelExporter 节点)。
## 2. 确保所有 'EnemySpawnPoint' 节点都被添加到了 "spawners" 组中。
## 3. 确保所有预设的 'Pipe' 节点都被添加到了 "pipes" 组中。
## 4. 在编辑器中选中挂载此脚本的节点，然后在检查器(Inspector)中设置 'Export Path'，
##    例如："res://levels/data/level_01.json"。
## 5. 勾选 'Export Now' 复选框，脚本将自动执行导出并将该复选框重置为false。
##

@export_group("Settings")
@export_file("*.json") var export_path: String = "res://levels/data/level_01.json"

@export_group("Actions")
@export var export_now: bool = false:
	set(value):
		if value:
			_export_level_data()
			# 异步重置，防止Godot编辑器在处理时卡顿
			call_deferred("_reset_export_flag")

func _reset_export_flag():
	export_now = false


func _export_level_data():
	if not get_tree() or not get_owner():
		print("错误: 无法在没有场景树或所有者(owner)的情况下导出。请确保此节点是某个场景的一部分。")
		return

	var scene_root = get_owner()
	print("开始从场景根节点 '%s' 导出关卡数据..." % scene_root.name)
	
	# 1. 定义数据结构
	var level_data = {
		"level_name": scene_root.name, # 使用场景根节点名作为默认关卡名
		"starting_resources": 250, # 默认初始资源，可以手动修改JSON文件
		"initial_delay": 5.0,      # 默认的战前准备时间
		"game_time_limit": 300.0,  # 默认的游戏时间限制 (5分钟)
		"spawners": [],
		"pipes": [], # 新增：用于存放预设管道
		"waves": []
	}

	# 2. 搜集所有生成点和路径
	var spawners = get_tree().get_nodes_in_group("spawners")
	if spawners.is_empty():
		print("警告: 在 'spawners' 组中没有找到任何节点。\n")
	
	for spawner in spawners:
		var path_nodes_in_spawner: Array[Path2D] = []
		for child in spawner.get_children():
			if child is Path2D:
				path_nodes_in_spawner.append(child)
		
		if path_nodes_in_spawner.is_empty():
			print("警告: 在 %s 中没有找到任何的 Path2D 子节点，已跳过。" % spawner.name)
			continue
			
		var all_paths_data = []
		for path_node in path_nodes_in_spawner:
			var single_path_points = []
			if path_node.curve:
				for i in range(path_node.curve.get_point_count()):
					# 路径点是相对于Path2D节点的，我们需要将其转换为全局坐标
					var global_pos = path_node.to_global(path_node.curve.get_point_position(i))
					single_path_points.append([global_pos.x, global_pos.y])
			all_paths_data.append(single_path_points)
		
		var spawner_global_pos = spawner.global_position
		level_data["spawners"].append({
			# 保存生成器本身的全局坐标
			"position": [spawner_global_pos.x, spawner_global_pos.y],
			"paths": all_paths_data
		})

	# 2.5. 搜集所有预设管道
	var pipes = get_tree().get_nodes_in_group("pipes")
	if pipes.is_empty():
		print("信息: 未在 'pipes' 组中找到任何预设管道节点。")
	
	for pipe in pipes:
		if not pipe is Pipe: continue # 确保是Pipe节点
		
		var direction_key = Pipe.Direction.keys()[pipe.direction_enum]
		var type_key = Pipe.PipeType.keys()[pipe.pipe_type]
		
		level_data["pipes"].append({
			"name": pipe.name,
			"type": type_key,
			"position": [pipe.global_position.x, pipe.global_position.y],
			"direction": direction_key
		})
		
	# 3. 搜集来自 WaveManager 的配置和波数信息
	# 从场景根节点查找WaveManager
	var wave_manager = scene_root.find_child("WaveManager", true, false)
	if wave_manager:
		# 抓取初始资源
		if "starting_resources" in wave_manager:
			level_data["starting_resources"] = wave_manager.starting_resources
			print("从 WaveManager 成功读取 starting_resources: %s" % wave_manager.starting_resources)
		else:
			print("警告: 在 WaveManager 中未找到 'starting_resources' 属性，将使用默认值。")
			
		# 抓取游戏时间限制
		if "game_time_limit" in wave_manager:
			level_data["game_time_limit"] = wave_manager.game_time_limit
			print("从 WaveManager 成功读取 game_time_limit: %s" % wave_manager.game_time_limit)
		else:
			print("警告: 在 WaveManager 中未找到 'game_time_limit' 属性，将使用默认值。")

		# 抓取初始延迟 (initial_delay)
		if "initial_delay" in wave_manager:
			level_data["initial_delay"] = wave_manager.initial_delay
			print("从 WaveManager 成功读取 initial_delay: %s" % wave_manager.initial_delay)
		else:
			print("警告: 在 WaveManager 中未找到 'initial_delay' 属性，将使用默认值。")

		# 在 @tool 模式下，我们必须直接访问导出变量，而不是调用任何函数（包括 'get' 或 'has'）。
		var waves_array = wave_manager.waves
		if waves_array and not waves_array.is_empty():
			var exported_waves = []
			for wave_resource in waves_array:
				if not wave_resource: continue # 跳过空条目
				
				var wave_data = {
					"enemies": [],
					# 必须使用 .get() 来访问非 @tool 脚本资源的属性
					"default_enemy_count": wave_resource.get("default_enemy_count"),
					"default_spawn_interval": wave_resource.get("default_spawn_interval"),
					"post_wave_delay": wave_resource.get("post_wave_delay")
				}
				
				# 处理默认的敌人生成信息
				var spawn_infos = wave_resource.get("default_spawn_infos")
				if spawn_infos:
					for enemy_spawn_info in spawn_infos:
						if not enemy_spawn_info: continue
						
						var enemy_type_name = "Unknown"
						# 必须使用 .get()
						var enemy_scene: PackedScene = enemy_spawn_info.get("enemy_scene")
						if enemy_scene:
							var path_parts = enemy_scene.resource_path.split("/")
							if not path_parts.is_empty():
								enemy_type_name = path_parts[path_parts.size() - 1].replace(".tscn", "")
						
						wave_data["enemies"].append({
							"type": enemy_type_name,
							"weight": enemy_spawn_info.get("weight")
						})
				
				exported_waves.append(wave_data)
			level_data["waves"] = exported_waves
			print("已直接从WaveManager的'waves'属性成功解析波数信息。")
		else:
			print("警告: WaveManager节点上的 'waves' 导出属性为空或不存在。波数数据将为空。")
	else:
		print("警告: 未在场景中找到 'WaveManager' 节点。波数数据将为空。")
		
	# 4. 将字典转换为JSON字符串
	var json_string = JSON.stringify(level_data, "\t") # 使用制表符进行缩进，方便阅读

	# 5. 确保导出目录存在
	var dir_path = export_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	# 6. 写入文件
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("关卡数据成功导出到: ", export_path)
	else:
		printerr("导出关卡数据失败！无法写入文件: %s, 错误码: %s" % [export_path, FileAccess.get_open_error()])
