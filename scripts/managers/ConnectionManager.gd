extends Node

signal connection_made(pipe_type: int) # 新增信号：当有新连接建立时发出

@export var red_pipe_repair_rate: float = 1.0  # Red pipes generate repair value

var _connections: Dictionary = {}
var _grid_manager: GridManager

func _ready() -> void:
	DebugManager.register_category("ConnectionManager", false)
	_grid_manager = get_node("/root/GridManager")
	if not _grid_manager:
		printerr("ConnectionManager: GridManager not found!")

func _process(delta: float):
	if GameManager.is_game_over(): return
	if not _grid_manager: return
	
	var total_red_pipe_rate: float = 0.0
	var total_blue_pipe_rate: float = 0.0
	
	# 遍历所有连接并检查其路径完整性
	for connection_key in _connections.keys():
		var connection = _connections[connection_key]
		
		# --- 安全检查：确保连接中的对象在场景切换时仍然有效 ---
		if not is_instance_valid(connection.pipe1):
			continue # 如果对象已被释放，则跳过此连接的处理
		
		var path_to_check = connection.path
		
		if _grid_manager.is_path_intact(path_to_check):
			var pipe1 = connection.pipe1
			var connection_multiplier = connection.get("multiplier", 1.0) # 获取线路乘数，默认为1.0
			
			# 根据管道类型累加各自的速率，并乘以线路乘数
			if connection.type == Pipe.PipeType.LIFE: # Red Pipe (修复值)
				total_red_pipe_rate += pipe1.resource_per_second * connection_multiplier
			elif connection.type == Pipe.PipeType.SUPPLY: # Blue Pipe (资源)
				total_blue_pipe_rate += pipe1.resource_per_second * connection_multiplier
	
	# 根据累加的总速率生成修复值
	if total_red_pipe_rate > 0:
		GameManager.add_repair_value(total_red_pipe_rate * delta)
		
	# 根据累加的总速率生成资源
	if total_blue_pipe_rate > 0:
		GameManager.add_resource_value(total_blue_pipe_rate * delta)

# --- Public API ---
func reset():
	_connections.clear()
	DebugManager.dprint("ConnectionManager", "ConnectionManager state has been reset.")



## 为指定桥梁所在的连接线路上应用加速乘数
func apply_boost_to_connection_of_bridge(bridge: Bridge, rate_multiplier: float):
	for connection_key in _connections.keys():
		var connection = _connections[connection_key]
		# 检查桥梁的 grid_pos 是否在该连接的路径中
		if connection.path.has(bridge.grid_pos):
			# 找到连接，更新其乘数
			# 这里我们只是简单地乘以新的乘数，您可以根据需要调整逻辑
			# 例如，可以存储所有应用的乘数，或限制最大乘数
			connection.multiplier = connection.get("multiplier", 1.0) * rate_multiplier
			print("连接 %s 的速率乘数已更新为 %s" % [connection_key, connection.multiplier])
			return
	print("ConnectionManager: 未找到桥梁 %s 所在的连接线路。" % bridge.name)

## 辅助函数：判断桥梁是否位于一个激活的连接线路上
func is_bridge_on_active_line(bridge: Bridge) -> bool:
	print("DEBUG [ConnectionManager]: **检查内部状态** _connections: %s" % _connections)

	if not is_instance_valid(bridge):
		print("DEBUG [ConnectionManager]: is_bridge_on_active_line called with invalid bridge.")
		return false
	
	var bridge_pos = bridge.grid_pos
	print("DEBUG [ConnectionManager]: 正在检查位于 %s 的桥梁是否在激活的线路上..." % bridge_pos)

	for connection_key in _connections.keys():
		var connection = _connections[connection_key]
		var connection_path = connection.path
		
		print("DEBUG [ConnectionManager]:  -> 正在匹配线路 %s (路径: %s)" % [connection_key, connection_path])
		
		if connection_path.has(bridge_pos):
			print("DEBUG [ConnectionManager]:  --> 找到！桥梁在此线路路径上。正在检查线路是否完整...")
			var is_intact = _grid_manager.is_path_intact(connection_path)
			print("DEBUG [ConnectionManager]:  --> _grid_manager.is_path_intact 返回: %s" % is_intact)
			if is_intact:
				print("DEBUG [ConnectionManager]:  ---> 线路完整。最终返回: true")
				return true # 找到了，并且线路是完整的
			else:
				print("DEBUG [ConnectionManager]:  ---> 线路已损坏。继续检查下一条线路...")
		# 如果不在此路径上，则继续循环，这是正常行为
			
	print("DEBUG [ConnectionManager]: 桥梁 %s 未在任何已连接的线路中找到。最终返回: false" % bridge_pos)
	return false


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
		"path": path,
		"multiplier": 1.0 # 初始化线路乘数
	}
	
	pipe1.on_connected()
	pipe2.on_connected()
	
	print("连接已注册: ", pipe1.name, " <-> ", pipe2.name)
	emit_signal("connection_made", pipe1.pipe_type) # 发出信号


func remove_connection(pipe1: Pipe, pipe2: Pipe):
	var id1 = pipe1.get_instance_id()
	var id2 = pipe2.get_instance_id()
	
	var connection_key = "%s_%s" % [min(id1, id2), max(id1, id2)]
	
	if _connections.has(connection_key):
		_connections.erase(connection_key)
		print("连接已移除: ", pipe1.name, " <-> ", pipe2.name)
	else:
		print("ConnectionManager: Attempted to remove non-existent connection between %s and %s" % [pipe1.name, pipe2.name])
