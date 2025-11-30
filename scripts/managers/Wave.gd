extends Resource
class_name Wave

# This resource defines the properties of a single enemy wave.

# An array of enemy types that can spawn in this wave.
# The spawner will use the weights from this list.
@export var enemy_spawn_infos: Array[EnemySpawnInfo]

# The total number of enemies to spawn in this wave.
@export var enemy_count: int = 10

# The time interval between each enemy spawn during this wave.
@export var spawn_interval: float = 1.0

# The delay in seconds after this wave is completed before the next one starts.
@export var post_wave_delay: float = 5.0
