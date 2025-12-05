extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_finished(wave_number: int)
signal all_waves_completed

@export var waves: Array[Wave]
@export var spawners: Array[Node]

@onready var _wave_timer: Timer = $WaveTimer

var _current_wave_index: int = -1
var _is_running: bool = false
var _active_spawners_count: int = 0

func _ready() -> void:
	if not _wave_timer:
		printerr("WaveManager requires a child Timer node named 'WaveTimer'.")
		return
	_wave_timer.timeout.connect(_start_next_wave)
	
	await get_tree().create_timer(0.1).timeout
	
	# Connect to other nodes that need to react to waves
	_connect_to_listeners()
	
	start_wave_system()

func _connect_to_listeners():
	# Find the particle background and connect to it.
	# This is more robust than having the listener try to find the manager.
	var particle_bg = get_tree().get_root().find_child("ParticleBackground", true, false)
	if particle_bg and particle_bg.has_method("_on_wave_started"):
		wave_started.connect(particle_bg._on_wave_started)
	else:
		print("WaveManager did not find ParticleBackground, or it's missing the '_on_wave_started' method.")

func start_wave_system():
	if waves.is_empty():
		printerr("WaveManager has no waves configured.")
		return
	if spawners.is_empty():
		printerr("WaveManager has no spawners configured.")
		return

	for spawner in spawners:
		if not spawner.has_signal("spawner_finished"):
			printerr("Spawner %s is missing the 'spawner_finished' signal." % spawner.name)
			continue
		if not spawner.spawner_finished.is_connected(_on_spawner_finished):
			spawner.spawner_finished.connect(_on_spawner_finished)

	_current_wave_index = -1
	_is_running = true
	_start_next_wave()

func stop_wave_system():
	_is_running = false
	for spawner in spawners:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
	if _wave_timer.is_started():
		_wave_timer.stop()
	print("Wave system stopped.")

func _start_next_wave():
	if not _is_running: return

	_current_wave_index += 1
	if _current_wave_index >= waves.size():
		print("All waves completed!")
		emit_signal("all_waves_completed")
		_is_running = false
		return

	var current_wave: Wave = waves[_current_wave_index]
	_active_spawners_count = 0

	emit_signal("wave_started", _current_wave_index + 1)
	print("Starting Wave ", _current_wave_index + 1)

	# For each spawner, find its config and start it if it has a quota.
	for spawner in spawners:
		# --- 新增：根据波数设置路径 ---
		if spawner.has_method("get_path_count") and spawner.has_method("set_active_path_by_index"):
			var path_count = spawner.get_path_count()
			if path_count > 0:
				# 使用波数索引来决定路径，如果波数超过路径数则循环使用
				var new_path_index = _current_wave_index % path_count
				spawner.set_active_path_by_index(new_path_index)
		# ---------------------------------
		
		var override_config = _get_override_for_spawner(current_wave, spawner)
		
		var enemy_infos: Array[EnemySpawnInfo]
		var spawn_interval: float
		var count_for_this_spawner: int

		if override_config:
			enemy_infos = override_config.override_spawn_infos
			count_for_this_spawner = override_config.override_enemy_count
			spawn_interval = override_config.override_spawn_interval if override_config.override_spawn_interval > 0 else current_wave.default_spawn_interval
		else:
			enemy_infos = current_wave.default_spawn_infos
			count_for_this_spawner = current_wave.default_enemy_count
			spawn_interval = current_wave.default_spawn_interval
		
		if count_for_this_spawner > 0:
			_active_spawners_count += 1
			if spawner.has_method("start_spawning"):
				spawner.start_spawning(enemy_infos, spawn_interval, count_for_this_spawner)
	
	if _active_spawners_count == 0:
		print("Wave %s has no active spawners. Skipping." % (_current_wave_index + 1))
		_finish_current_wave()

func _on_spawner_finished(spawner):
	if not _is_running: return
	
	print("Spawner %s has finished its quota." % spawner.name)
	_active_spawners_count -= 1
	
	if _active_spawners_count <= 0:
		_finish_current_wave()

func _finish_current_wave():
	if not _is_running: return
	
	emit_signal("wave_finished", _current_wave_index + 1)
	print("Wave ", _current_wave_index + 1, " finished.")
	
	# This is now redundant as spawners stop themselves, but good for safety.
	for spawner in spawners:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()

	var post_wave_delay = waves[_current_wave_index].post_wave_delay
	_wave_timer.start(post_wave_delay)

# --- Helper Methods ---

func _get_override_for_spawner(wave: Wave, spawner: Node) -> SpawnerWaveConfig:
	var spawner_path = get_path_to(spawner)
	for override in wave.spawner_overrides:
		if override.spawner_nodepath == spawner_path:
			return override
	return null
