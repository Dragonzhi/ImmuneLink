# LevelLoader.gd
extends Node

class_name LevelLoader

const ENEMY_SPAWN_POINT_SCENE = preload("res://scenes/others/enemy_spawn_point.tscn")
const PIPE_SCENE = preload("res://scenes/pipes/Pipe.tscn")
const WAVE_CLASS = preload("res://scripts/managers/Wave.gd")
const ENEMY_SPAWN_INFO_CLASS = preload("res://scripts/others/EnemySpawnInfo.gd")

func load_level(level_path: String):
	var file = FileAccess.open(level_path, FileAccess.READ)
	if not file:
		printerr("Failed to open level file: ", level_path)
		return null

	var content = file.get_as_text()
	file.close()

	var json_result = JSON.parse_string(content)
	if json_result == null:
		printerr("Failed to parse JSON from level file: ", level_path)
		return null

	var level_data = json_result as Dictionary
	if level_data.is_empty():
		printerr("Level data is empty: ", level_path)
		return null

	# Create a new Node2D to hold the loaded level elements
	var loaded_level_root = Node2D.new()
	loaded_level_root.name = level_data.get("level_name", "LoadedLevel")
	
	# Set starting resources (if GameManager can access this or pass it)
	var starting_resources = level_data.get("starting_resources", 250)
	# GameManager.set_starting_resources(starting_resources) # This would need a reference to GameManager

	# Load Spawners
	var spawners_data = level_data.get("spawners", [])
	for spawner_info in spawners_data:
		var spawner_instance = ENEMY_SPAWN_POINT_SCENE.instantiate()
		# Position is stored as [x, y] in JSON
		var pos_array = spawner_info.get("position", [0, 0])
		spawner_instance.global_position = Vector2(pos_array[0], pos_array[1])
		
		# Add paths to the spawner
		var paths_data = spawner_info.get("paths", [])
		# Remove default paths from the scene, as we are loading custom ones
		for child in spawner_instance.get_children():
			if child is Path2D and child.name.begins_with("Path"):
				child.queue_free()
				
		for i in range(paths_data.size()):
			var path_data = paths_data[i]
			if not path_data.is_empty():
				var path2d = Path2D.new()
				path2d.name = "Path%02d" % (i + 1) # Naming like Path01, Path02
				var curve = Curve2D.new()
				for point_array in path_data:
					curve.add_point(Vector2(point_array[0], point_array[1]))
				path2d.curve = curve
				spawner_instance.add_child(path2d)
				# Need to add to group "spawners" for the game logic to pick it up
				spawner_instance.add_to_group("spawners") # Spawners are added to this group by default in the scene
		loaded_level_root.add_child(spawner_instance)

	# Load Pipes
	var pipes_data = level_data.get("pipes", [])
	for pipe_info in pipes_data:
		var pipe_instance = PIPE_SCENE.instantiate()
		pipe_instance.name = pipe_info.get("name", "Pipe")
		
		var pos_array = pipe_info.get("position", [0, 0])
		pipe_instance.global_position = Vector2(pos_array[0], pos_array[1])
		
		var type_str = pipe_info.get("type", "NORMAL")
		# Ensure PipeType enum exists and set it
		if type_str in Pipe.PipeType: # Accessing static enum directly
			pipe_instance.pipe_type = Pipe.PipeType[type_str]
		else:
			printerr("Unknown pipe type: ", type_str)
		
		var direction_str = pipe_info.get("direction", "UP")
		# Ensure Direction enum exists and set it
		if direction_str in Pipe.Direction: # Accessing static enum directly
			pipe_instance.direction_enum = Pipe.Direction[direction_str]
		else:
			printerr("Unknown pipe direction: ", direction_str)

		loaded_level_root.add_child(pipe_instance)
		pipe_instance.add_to_group("pipes") # Add to group "pipes" for the game logic
		
	# Load Waves
	var loaded_waves: Array[WAVE_CLASS] = []
	var waves_data = level_data.get("waves", [])
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
			# Need to convert enemy_type string back to PackedScene
			# Assuming enemy scenes are in "res://scenes/enemies/" + enemy_type + ".tscn"
			if not enemy_type.is_empty():
				var enemy_scene_path = "res://scenes/enemies/" + enemy_type + ".tscn"
				if ResourceLoader.exists(enemy_scene_path):
					new_enemy_spawn_info.enemy_scene = load(enemy_scene_path)
				else:
					printerr("Enemy scene not found: ", enemy_scene_path)
			# The 'weight' property in EnemySpawnInfo needs to be set.
			# In LevelExporter.gd, it exported 'weight', so we should load it here.
			new_enemy_spawn_info.weight = enemy_info_entry.get("weight", 1) 
			loaded_enemy_spawn_infos.append(new_enemy_spawn_info)
		
		new_wave.default_spawn_infos = loaded_enemy_spawn_infos
		loaded_waves.append(new_wave)
		
	return {
		"level_root": loaded_level_root,
		"waves": loaded_waves,
		"starting_resources": starting_resources
	}

func _ready():
	# Example usage (for testing purposes, remove in production)
	# var loaded_data = load_level("res://levels/data/main.json")
	# if loaded_data:
	#     get_tree().root.add_child(loaded_data.level_root)
	#     print("Level 'main.json' loaded successfully!")
	#     # Now you can access loaded_data.waves and loaded_data.starting_resources
	pass
