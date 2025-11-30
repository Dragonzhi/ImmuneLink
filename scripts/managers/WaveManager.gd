extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_finished(wave_number: int)
signal all_waves_completed

@export var waves: Array[Wave]
@export var spawners: Array[Node]

@onready var _wave_timer: Timer = $WaveTimer

var _current_wave_index: int = -1
var _enemies_spawned_in_current_wave: int = 0
var _total_enemies_in_current_wave: int = 0
var _is_running: bool = false

func _ready() -> void:
    if not _wave_timer:
        printerr("WaveManager requires a child Timer node named 'WaveTimer'.")
        return
    _wave_timer.timeout.connect(_start_next_wave)
    
    await get_tree().create_timer(0.1).timeout
    start_wave_system()

func start_wave_system():
    if waves.is_empty():
        printerr("WaveManager has no waves configured.")
        return
    if spawners.is_empty():
        printerr("WaveManager has no spawners configured.")
        return

    for spawner in spawners:
        if not spawner.has_signal("enemy_spawned"):
            printerr("Spawner %s is missing the 'enemy_spawned' signal." % spawner.name)
            continue
        if not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
             spawner.enemy_spawned.connect(_on_enemy_spawned)

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
    _enemies_spawned_in_current_wave = 0
    _total_enemies_in_current_wave = _calculate_total_enemies_for_wave(current_wave)

    if _total_enemies_in_current_wave == 0:
        print("Wave %s has no enemies to spawn. Skipping." % (_current_wave_index + 1))
        _finish_current_wave()
        return

    emit_signal("wave_started", _current_wave_index + 1)
    print("Starting Wave %s with %s enemies." % [_current_wave_index + 1, _total_enemies_in_current_wave])

    # For each spawner, find its config (override or default) and start it.
    for spawner in spawners:
        var override_config = _get_override_for_spawner(current_wave, spawner)
        
        var enemy_infos: Array[EnemySpawnInfo]
        var spawn_interval: float

        if override_config:
            enemy_infos = override_config.override_spawn_infos
            spawn_interval = override_config.override_spawn_interval if override_config.override_spawn_interval > 0 else current_wave.default_spawn_interval
        else:
            enemy_infos = current_wave.default_spawn_infos
            spawn_interval = current_wave.default_spawn_interval
        
        if spawner.has_method("start_spawning"):
            spawner.start_spawning(enemy_infos, spawn_interval)

func _on_enemy_spawned():
    if not _is_running: return

    _enemies_spawned_in_current_wave += 1
    
    if _enemies_spawned_in_current_wave >= _total_enemies_in_current_wave:
        _finish_current_wave()

func _finish_current_wave():
    if not _is_running: return
    
    emit_signal("wave_finished", _current_wave_index + 1)
    print("Wave ", _current_wave_index + 1, " finished.")
    
    for spawner in spawners:
        if spawner.has_method("stop_spawning"):
            spawner.stop_spawning()

    var post_wave_delay = waves[_current_wave_index].post_wave_delay
    _wave_timer.start(post_wave_delay)

# --- Helper Methods ---

func _calculate_total_enemies_for_wave(wave: Wave) -> int:
    var total_enemies = 0
    var overridden_spawners = []

    # Add counts from overrides
    for override in wave.spawner_overrides:
        if get_node_or_null(override.spawner_nodepath):
            total_enemies += override.override_enemy_count
            overridden_spawners.append(override.spawner_nodepath)
        else:
            push_warning("Wave %s has an override for a non-existent spawner: %s" % [_current_wave_index + 1, override.spawner_nodepath])
    
    # Add counts from spawners that DON'T have an override
    for spawner in spawners:
        if not get_path_to(spawner) in overridden_spawners:
            total_enemies += wave.default_enemy_count
            
    return total_enemies

func _get_override_for_spawner(wave: Wave, spawner: Node) -> SpawnerWaveConfig:
    var spawner_path = get_path_to(spawner)
    for override in wave.spawner_overrides:
        if override.spawner_nodepath == spawner_path:
            return override
    return null
