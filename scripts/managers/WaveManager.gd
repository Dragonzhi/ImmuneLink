extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_finished(wave_number: int)
signal all_waves_completed

@export var waves: Array[Wave]
@export var spawners: Array[Node]
@export var loop_waves: bool = false
@export var auto_start_on_ready: bool = true
@export var initial_delay: float = 5.0

@onready var _wave_timer: Timer = $WaveTimer

var _current_wave_index: int = -1
var _is_running: bool = false
var _active_spawners_count: int = 0

func _ready() -> void:
	DebugManager.register_category("WaveManager", false) # 注册调试类别
	if not _wave_timer:
		printerr("WaveManager requires a child Timer node named 'WaveTimer'.")
		return
	# Ensure the signal is connected only once
	if _wave_timer.timeout.is_connected(_start_next_wave):
		_wave_timer.timeout.disconnect(_start_next_wave)
	_wave_timer.timeout.connect(_start_next_wave)
	
	_initialize_system()
	
	if auto_start_on_ready:
		start_spawning()

func _initialize_system():
	# Connect to other nodes that need to react to waves
	_connect_to_listeners()

	if waves.is_empty() or spawners.is_empty():
		return

	for spawner in spawners:
		if not spawner.has_signal("spawner_finished"):
			printerr("Spawner %s is missing the 'spawner_finished' signal." % spawner.name)
			continue
		if not spawner.spawner_finished.is_connected(_on_spawner_finished):
			spawner.spawner_finished.connect(_on_spawner_finished)
			
	_current_wave_index = -1

func _connect_to_listeners():
	# Find the particle background and connect to it.
	var particle_bg = get_tree().get_root().find_child("ParticleBackground", true, false)
	if particle_bg and particle_bg.has_method("_on_wave_started"):
		wave_started.connect(particle_bg._on_wave_started)
	else:
		DebugManager.dprint("WaveManager", "WaveManager 未找到 ParticleBackground，或其缺少 '_on_wave_started' 方法。")

# --- Public Control API ---

## 开始自动波次生成
func start_spawning(delay: float = -1.0):
	if waves.is_empty() or spawners.is_empty():
		printerr("WaveManager has no waves or spawners configured. Cannot start.")
		return
		
	var start_delay = initial_delay if delay < 0 else delay
	DebugManager.dprint("WaveManager", "波次系统将在 %s 秒后启动。" % start_delay)
	
	_is_running = true
	_wave_timer.start(start_delay)

## 停止所有波次和生成
func stop_wave_system():
	_is_running = false
	for spawner in spawners:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
	if not _wave_timer.is_stopped():
		_wave_timer.stop()
	DebugManager.dprint("WaveManager", "波次系统已停止。")

## 手动触发下一波
func trigger_next_wave():
	if not _is_running:
		_is_running = true
	
	if not _wave_timer.is_stopped():
		_wave_timer.stop()
	
	_start_next_wave()

# --- Internal Wave Logic ---

func _start_next_wave():
	_wave_timer.stop() # 确保计时器在处理波次逻辑前已停止，防止重复触发
	DebugManager.dprint("WaveManager", "_start_next_wave 被调用。")
	if not _is_running: return

	_current_wave_index += 1
	if _current_wave_index >= waves.size():
		if loop_waves:
			DebugManager.dprint("WaveManager", "所有波次已完成。循环回到第一波。")
			_current_wave_index = 0 # 重置为第一波
		else:
			DebugManager.dprint("WaveManager", "所有波次已完成！")
			emit_signal("all_waves_completed")
			_is_running = false
			return

	var current_wave: Wave = waves[_current_wave_index]
	_active_spawners_count = 0

	emit_signal("wave_started", _current_wave_index + 1)
	SoundManager.play_sfx("wave_come") # 播放新波次音效
	DebugManager.dprint("WaveManager", "正在启动第 %s 波。" % (_current_wave_index + 1))
	VhsMonitorEffect.play_glitch()
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
				DebugManager.dprint("WaveManager", "通知生成器 '%s' 开始生成。" % spawner.name)
				spawner.start_spawning(enemy_infos, spawn_interval, count_for_this_spawner)
	
	if _active_spawners_count == 0:
		DebugManager.dprint("WaveManager", "第 %s 波没有活跃的生成器。跳过。" % (_current_wave_index + 1))
		_finish_current_wave()

func _on_spawner_finished(spawner):
	DebugManager.dprint("WaveManager", "收到生成器 '%s' 发出的 'spawner_finished' 信号。" % spawner.name)
	if not _is_running: return
	
	DebugManager.dprint("WaveManager", "生成器 '%s' 已完成其配额。" % spawner.name)
	_active_spawners_count -= 1
	
	if _active_spawners_count <= 0:
		_finish_current_wave()

func _finish_current_wave():
	DebugManager.dprint("WaveManager", "_finish_current_wave 被调用。")
	if not _is_running: return
	
	emit_signal("wave_finished", _current_wave_index + 1)
	DebugManager.dprint("WaveManager", "第 %s 波次已完成。" % (_current_wave_index + 1))
	
	# This is now redundant as spawners stop themselves, but good for safety.
	for spawner in spawners:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()

	var post_wave_delay = waves[_current_wave_index].post_wave_delay
	DebugManager.dprint("WaveManager", "正在为下一波启动计时器，延迟：%s。" % post_wave_delay)
	_wave_timer.start(post_wave_delay)

# --- Helper Methods ---

func _get_override_for_spawner(wave: Wave, spawner: Node) -> SpawnerWaveConfig:
	var spawner_path = get_path_to(spawner)
	for override in wave.spawner_overrides:
		if override.spawner_nodepath == spawner_path:
			return override
	return null
