extends Node
class_name WaveManager

# Emitted when a new wave starts. Passes the wave number (1-based).
signal wave_started(wave_number: int)

# Emitted when all enemies of a wave have been spawned. Passes the wave number (1-based).
signal wave_finished(wave_number: int)

# Emitted when the last wave in the sequence is completed.
signal all_waves_completed

# An array of Wave resources that define the sequence of waves.
# You will create these resources in the editor and assign them here.
@export var waves: Array[Wave]

# A reference to all spawners in the scene that this manager will control.
# You will need to assign the spawner nodes to this array in the editor.
@export var spawners: Array[Node]

@onready var _wave_timer: Timer = $WaveTimer # Used for post-wave delays

var _current_wave_index: int = -1
var _enemies_spawned_in_current_wave: int = 0
var _is_running: bool = false

func _ready() -> void:
    if not _wave_timer:
        printerr("WaveManager requires a child Timer node named 'WaveTimer'.")
        return
    _wave_timer.timeout.connect(_start_next_wave)
    
    # Small delay to ensure all other nodes are ready
    await get_tree().create_timer(0.1).timeout
    start_wave_system()

func start_wave_system():
    """Starts the wave sequence."""
    if waves.is_empty():
        printerr("WaveManager has no waves configured.")
        return
    if spawners.is_empty():
        printerr("WaveManager has no spawners configured.")
        return

    # Connect to the 'enemy_spawned' signal from each spawner
    for spawner in spawners:
        # The spawner script needs to be modified to have this signal
        if not spawner.has_signal("enemy_spawned"):
            printerr("Spawner %s is missing the 'enemy_spawned' signal." % spawner.name)
            continue
        if not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
             spawner.enemy_spawned.connect(_on_enemy_spawned)

    _current_wave_index = -1
    _is_running = true
    _start_next_wave()

func stop_wave_system():
    """Stops the wave system completely."""
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

    var current_wave = waves[_current_wave_index]
    _enemies_spawned_in_current_wave = 0
    
    emit_signal("wave_started", _current_wave_index + 1)
    print("Starting Wave ", _current_wave_index + 1)

    # Configure and start all spawners for the current wave
    for spawner in spawners:
        if spawner.has_method("start_spawning"):
            spawner.start_spawning(current_wave.enemy_spawn_infos, current_wave.spawn_interval)

func _on_enemy_spawned():
    if not _is_running: return

    _enemies_spawned_in_current_wave += 1
    
    var current_wave = waves[_current_wave_index]
    if _enemies_spawned_in_current_wave >= current_wave.enemy_count:
        _finish_current_wave()

func _finish_current_wave():
    if not _is_running: return
    
    emit_signal("wave_finished", _current_wave_index + 1)
    print("Wave ", _current_wave_index + 1, " finished.")
    
    # Stop all spawners
    for spawner in spawners:
        if spawner.has_method("stop_spawning"):
            spawner.stop_spawning()

    # Start timer for the next wave
    var post_wave_delay = waves[_current_wave_index].post_wave_delay
    _wave_timer.start(post_wave_delay)
