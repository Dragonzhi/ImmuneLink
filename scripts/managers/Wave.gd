extends Resource
class_name Wave

# This resource defines the properties of a single enemy wave.

# --- Default Settings ---
# These settings will be used by any spawner that doesn't have a specific override below.
@export_group("Default Settings")
@export var default_spawn_infos: Array[EnemySpawnInfo]
@export var default_enemy_count: int = 10
@export var default_spawn_interval: float = 1.0

# --- Overrides ---
# A list of special configurations for specific spawners.
@export_group("Spawner Overrides")
@export var spawner_overrides: Array[SpawnerWaveConfig]

# --- General ---
@export_group("General")
# The delay in seconds after this wave is completed before the next one starts.
@export var post_wave_delay: float = 5.0
