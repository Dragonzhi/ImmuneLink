extends Resource
class_name SpawnerWaveConfig

# This resource holds a set of override rules for a specific spawner during a wave.

# A NodePath to the EnemySpawnPoint node that this configuration applies to.
@export var spawner_nodepath: NodePath

# If this array is not empty, it will be used instead of the wave's default enemy list.
@export var override_spawn_infos: Array[EnemySpawnInfo]

# The total number of enemies this specific spawner should produce.
@export var override_enemy_count: int = 10

# If this value is greater than 0, it will override the wave's default spawn interval.
@export var override_spawn_interval: float = -1.0
