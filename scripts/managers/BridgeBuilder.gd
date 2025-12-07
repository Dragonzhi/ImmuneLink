extends Node2D
class_name  BridgeBuilder
const BridgeScene = preload("uid://de0pjmcrfoc5m")

# --- Exports ---
@export var build_delay: float = 0.05
@export var bridges_container: Node2D
@export var bridge_segment_cost: int = 10
@export var secondary_bridge_color: Color = Color(0.7, 0.7, 1.0) # 扩展桥梁的颜色

# --- OnReady Vars ---
@onready var preview_line: Line2D = $PreviewLine
@onready var build_timer: Timer = $BuildTimer
@onready var cost_label: Label = $CostLabel

# --- Node Refs ---
var grid_manager: GridManager
var connection_manager: ConnectionManager
var ui_manager: Node

# --- Build State ---
var build_mode: bool = false
var _is_building_secondary: bool = false
var start_pipe: Pipe = null
var start_bridge: Bridge = null
var start_pos: Vector2i
var start_direction: Vector2i # This is needed for pipe-to-pipe mode
var current_path: Array[Vector2i] = []

# --- Sequential Build State ---
var sequential_build_path: Array[Vector2i] = []
var path_connection_set: Dictionary = {}
var front_build_index: int = 0
var back_build_index: int = 0
var _pending_update_start_bridge: Bridge = null
var _pending_update_end_bridge: Bridge = null


func _ready() -> void:
	grid_manager = GridManager
	connection_manager = ConnectionManager
	ui_manager = get_node("/root/Main/UIManager")
	
	if not bridges_container: printerr("BridgeBuilder: 'bridges_container' not set!")
	if not grid_manager: printerr("BridgeBuilder: GridManager not found")
	if not connection_manager: printerr("BridgeBuilder: ConnectionManager not found")
	if not ui_manager: printerr("BridgeBuilder: UIManager not found")

	build_timer.wait_time = build_delay
	build_timer.timeout.connect(_on_BuildTimer_timeout)
	get_tree().get_root().mouse_exited.connect(_on_mouse_exited)
	
	cost_label.hide()

# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if not build_mode: return
	
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_handle_left_mouse_release(event)
	
	if cost_label.visible:
		cost_label.global_position = event.position + Vector2(5, 5)

func _handle_mouse_motion(event: InputEventMouseMotion):
	var new_grid_pos = grid_manager.world_to_grid(event.position)
	_update_cost_label()
	
	if current_path.is_empty() or new_grid_pos == current_path.back():
		return

	var last_grid_pos = current_path.back()
	var dx = abs(new_grid_pos.x - last_grid_pos.x)
	var dy = abs(new_grid_pos.y - last_grid_pos.y)

	if (dx + dy) == 1:
		_add_point_to_path(new_grid_pos)
	elif (dx > 0 or dy > 0):
		_interpolate_path_cardinal(last_grid_pos, new_grid_pos)
	
	_update_preview()

func _handle_left_mouse_release(event: InputEventMouseButton):
	var grid_pos = grid_manager.world_to_grid(event.position)
	var target_node = grid_manager.get_grid_object(grid_pos)

	var is_valid_pipe_target = (start_pipe and target_node is Pipe and target_node != start_pipe)
	var is_valid_bridge_target = (start_bridge and target_node is Bridge and target_node != start_bridge and target_node.current_bridge_state == Bridge.State.EXPANSION_WAITING)

	if is_valid_pipe_target or is_valid_bridge_target:
		_finish_building(target_node, grid_pos)
	else:
		_cancel_building()

# --- Path Logic ---

func _add_point_to_path(point: Vector2i):
	if not grid_manager.is_within_bounds(point): return
	if current_path.has(point):
		current_path = current_path.slice(0, current_path.find(point) + 1)
	else:
		current_path.append(point)

func _interpolate_path_cardinal(start: Vector2i, end: Vector2i):
	var current_pos = start
	while current_pos != end:
		var diff = end - current_pos
		var step = Vector2i.ZERO
		if abs(diff.x) > abs(diff.y): step.x = sign(diff.x)
		else: step.y = sign(diff.y)
		current_pos += step
		_add_point_to_path(current_pos)

# --- Build Process ---

func start_building(pipe: Pipe, pos: Vector2i, direction: Vector2i):
	if build_mode: return
	build_mode = true
	_is_building_secondary = false
	start_pipe = pipe
	start_bridge = null
	start_pos = pos
	start_direction = direction
	current_path = [pos]
	preview_line.visible = true
	cost_label.show()
	_update_cost_label()
	grid_manager.show_grid()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func start_building_from_bridge(bridge: Bridge):
	if build_mode: return
	build_mode = true
	_is_building_secondary = true
	start_bridge = bridge
	start_pipe = null
	start_pos = bridge.grid_pos
	start_direction = Vector2i.ZERO # Not used in this mode, determined dynamically
	current_path = [start_pos]
	preview_line.visible = true
	cost_label.show()
	_update_cost_label()
	grid_manager.show_grid()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func _finish_building(end_node: Node, end_pos: Vector2i):
	if not current_path.has(end_pos): _add_point_to_path(end_pos)

	if end_node is Pipe:
		# --- Pipe to Pipe Mode ---
		var end_pipe = end_node as Pipe
		var path_to_build = current_path
		
		# For pipes, we check the whole path, but must exclude start/end cells
		# which are occupied by the pipes themselves.
		var validation_path = path_to_build.slice(1, path_to_build.size() - 1)
		var validation_result = _validate_path_and_collect_items(validation_path)

		if not validation_result.buildable or start_pipe.pipe_type != end_pipe.pipe_type:
			_cancel_building()
			return

		var total_cost = path_to_build.size() * bridge_segment_cost
		if not GameManager.spend_resource_value(total_cost):
			print("建造失败: 资源不足!")
			_cancel_building()
			return
		
		# --- 拾取物品 ---
		for item in validation_result.items_to_collect:
			item.collect()
		
		SoundManager.play_sfx("pipe_yes") # 播放管道连接成功音效
		
		_setup_sequential_build(path_to_build, start_pipe.direction, end_pipe.direction)
		
		connection_manager.add_connection(start_pipe, end_pipe, path_to_build.duplicate())
		start_pipe.mark_pipe_as_used()
		end_pipe.mark_pipe_as_used()

	elif end_node is Bridge:
		# --- Bridge to Bridge Mode ---
		var end_bridge = end_node as Bridge
		var path_to_build = current_path.slice(1, current_path.size() - 1)
		
		var validation_result = _validate_path_and_collect_items(path_to_build)
		
		if not validation_result.buildable:
			_cancel_building()
			return

		var total_cost = path_to_build.size() * bridge_segment_cost
		if not GameManager.spend_resource_value(total_cost):
			print("建造失败: 资源不足!")
			_cancel_building()
			return
			
		if not (start_bridge and start_bridge.current_bridge_state == Bridge.State.EXPANSION_WAITING and end_bridge.current_bridge_state == Bridge.State.EXPANSION_WAITING):
			_cancel_building()
			GameManager.add_resource_value(total_cost) # Refund
			return
		
		if current_path.size() < 2:
			_cancel_building()
			GameManager.add_resource_value(total_cost) # Refund
			return
		
		# --- 拾取物品 ---
		for item in validation_result.items_to_collect:
			item.collect()
			
		SoundManager.play_sfx("bridge_connect") # 播放桥连接成功音效
			
		var dynamic_start_dir = current_path[0] - current_path[1]
		var dynamic_end_dir = current_path.back() - current_path[current_path.size() - 2]
		
		_setup_sequential_build(path_to_build, dynamic_start_dir, dynamic_end_dir)
		
		start_bridge.complete_expansion()
		end_bridge.complete_expansion()
		
		_pending_update_start_bridge = start_bridge
		_pending_update_end_bridge = end_bridge
	
	_reset_build_mode(false)
	build_timer.start()

func _validate_path_and_collect_items(path: Array) -> Dictionary:
	"""
	验证路径是否可建造，并收集路径上的所有物品。
	返回: {"buildable": bool, "items_to_collect": Array[Node]}
	"""
	var items = []
	for grid_pos in path:
		var node = grid_manager.get_grid_object(grid_pos)
		if node != null:
			if node is NKCell: # 允许穿过NK细胞
				items.append(node)
			else: # 其他任何障碍物都使路径无效
				return {"buildable": false, "items_to_collect": []}
	
	return {"buildable": true, "items_to_collect": items}


func _setup_sequential_build(path: Array, p_start_direction: Vector2i, p_end_direction: Vector2i):
	sequential_build_path = path
	path_connection_set.clear()
	for pos in path:
		path_connection_set[pos] = true

	# Add the "virtual" neighbors behind the start and end points to ensure
	# the first and last segments get the correct neighbor info.
	if not path.is_empty():
		path_connection_set[path[0] + p_start_direction] = true
		path_connection_set[path.back() + p_end_direction] = true
	
	front_build_index = 0
	back_build_index = sequential_build_path.size() - 1

func _on_BuildTimer_timeout():
	var build_finished = false
	
	if sequential_build_path.is_empty():
		build_finished = true
	elif front_build_index <= back_build_index:
		_create_single_bridge_segment(sequential_build_path[front_build_index], _is_building_secondary)
		front_build_index += 1
		
		if front_build_index - 1 != back_build_index:
			if back_build_index >= front_build_index:
				_create_single_bridge_segment(sequential_build_path[back_build_index], _is_building_secondary)
				back_build_index -= 1
	
	if front_build_index > back_build_index:
		build_finished = true

	if build_finished:
		build_timer.stop()
		
		if _pending_update_start_bridge and is_instance_valid(_pending_update_start_bridge):
			_pending_update_start_bridge.update_connections()
			_pending_update_start_bridge = null
		if _pending_update_end_bridge and is_instance_valid(_pending_update_end_bridge):
			_pending_update_end_bridge.update_connections()
			_pending_update_end_bridge = null
			
		sequential_build_path.clear()
		path_connection_set.clear()
		print("--- 桥梁建造完毕 ---")

func _create_single_bridge_segment(grid_pos: Vector2i, is_secondary_bridge: bool):
	var neighbors = {
		"north": path_connection_set.has(grid_pos + Vector2i.UP),
		"south": path_connection_set.has(grid_pos + Vector2i.DOWN),
		"east": path_connection_set.has(grid_pos + Vector2i.RIGHT),
		"west": path_connection_set.has(grid_pos + Vector2i.LEFT)
	}
	
	var bridge_segment = BridgeScene.instantiate() as Bridge
	bridges_container.add_child(bridge_segment)
	bridge_segment.global_position = grid_manager.grid_to_world(grid_pos)
	
	bridge_segment.is_secondary = is_secondary_bridge
	if is_secondary_bridge:
		bridge_segment.set_sprite_modulate(secondary_bridge_color)
		bridge_segment.secondary_color = secondary_bridge_color
	
	bridge_segment.setup_segment(grid_pos)
	bridge_segment.setup_bridge_tile(neighbors)

func _cancel_building():
	SoundManager.play_sfx("pipe_def") # 播放管道建造失败音效
	_reset_build_mode(true)

func _reset_build_mode(clear_path: bool):
	build_mode = false
	start_pipe = null
	start_bridge = null
	if clear_path: current_path.clear()
	preview_line.clear_points()
	preview_line.visible = false
	cost_label.hide()
	grid_manager.hide_grid()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_mouse_exited():
	if build_mode: _cancel_building()

func _update_preview():
	preview_line.clear_points()
	if current_path.size() < 2: return
	for grid_pos in current_path:
		preview_line.add_point(grid_manager.grid_to_world(grid_pos))

func _update_cost_label():
	var cost_path = current_path.slice(1)
	var current_cost = cost_path.size() * bridge_segment_cost
	var player_resources = GameManager.get_resource_value()
	
	cost_label.text = str(current_cost)
	
	if current_cost > player_resources:
		cost_label.modulate = Color.RED
	else:
		cost_label.modulate = Color.WHITE
