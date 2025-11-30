extends Node
class_name ConnectionManager

@export var red_pipe_repair_rate: float = 1.0  # Red pipes generate repair value
@export var blue_pipe_resource_rate: float = 2.0 # Blue pipes generate resources

var _connections: Dictionary = {}
var _grid_manager: GridManager

func _ready() -> void:
	_grid_manager = get_node("/root/Main/GridManager")
	if not _grid_manager:
		printerr("ConnectionManager: GridManager not found!")

func _process(delta: float):
	if not _grid_manager: return
	
	var active_red_connections = 0
	var active_blue_connections = 0
	
	# Iterate through all connections and check their path integrity
	for connection_key in _connections.keys():
		var connection = _connections[connection_key]
		# The path to check is the entire path of bridge segments.
		var path_to_check = connection.path
		
		print("ConnectionManager: Checking path: ", path_to_check)
		var is_intact = _grid_manager.is_path_intact(path_to_check)
		print("ConnectionManager: Path is intact? ", is_intact)
		
		if is_intact:
			if connection.type == 0: # Red Pipe
				active_red_connections += 1
			else: # Blue Pipe
				active_blue_connections += 1
	
	# Generate repair value
	if active_red_connections > 0:
		GameManager.add_repair_value(active_red_connections * red_pipe_repair_rate * delta)
		
	# Generate resources
	if active_blue_connections > 0:
		GameManager.add_resource_value(active_blue_connections * blue_pipe_resource_rate * delta)


func add_connection(pipe1: Pipe, pipe2: Pipe, path: Array[Vector2i]):
	var id1 = pipe1.get_instance_id()
	var id2 = pipe2.get_instance_id()
	
	# Create a consistent key for the pair of pipes
	var connection_key = "%s_%s" % [min(id1, id2), max(id1, id2)]
	
	if _connections.has(connection_key):
		# Connection already exists, maybe update path? For now, just print.
		print("ConnectionManager: Connection between %s and %s already exists." % [pipe1.name, pipe2.name])
		return
		
	_connections[connection_key] = {
		"pipe1": pipe1,
		"pipe2": pipe2,
		"type": pipe1.pipe_type,
		"path": path
	}
	
	pipe1.on_connected()
	pipe2.on_connected()
	
	print("连接已注册: ", pipe1.name, " <-> ", pipe2.name)


func remove_connection(pipe1: Pipe, pipe2: Pipe):
	var id1 = pipe1.get_instance_id()
	var id2 = pipe2.get_instance_id()
	
	var connection_key = "%s_%s" % [min(id1, id2), max(id1, id2)]
	
	if _connections.has(connection_key):
		_connections.erase(connection_key)
		print("连接已移除: ", pipe1.name, " <-> ", pipe2.name)
	else:
		print("ConnectionManager: Attempted to remove non-existent connection between %s and %s" % [pipe1.name, pipe2.name])
