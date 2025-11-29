extends Node2D
class_name BridgeBuilder

const BridgeScene = preload("res://scenes/bridge/bridge.tscn")

# --- Exports ---
@export var build_delay: float = 0.05
@export var bridges_container: Node2D
@export var bridge_segment_cost: int = 10

# --- OnReady Vars ---
@onready var preview_line: Line2D = $PreviewLine
@onready var build_timer: Timer = $BuildTimer

# --- Node Refs ---
var grid_manager: GridManager
var connection_manager: ConnectionManager
var ui_manager: Node

# --- Build State ---
var build_mode: bool = false
var start_pipe: Pipe = null
var start_pos: Vector2i
var current_path: Array[Vector2i] = []

# --- Sequential Build State ---
var sequential_build_path: Array[Vector2i] = []
var path_connection_set: Dictionary = {}
var front_build_index: int = 0
var back_build_index: int = 0


func _ready() -> void:
	grid_manager = get_node("/root/Main/GridManager")
	connection_manager = get_node("/root/Main/ConnectionManager")
	ui_manager = get_node("/root/Main/UIManager")
	
	if not bridges_container: printerr("BridgeBuilder: 'bridges_container' not set!")
	if not grid_manager: printerr("BridgeBuilder: GridManager not found")
	if not connection_manager: printerr("BridgeBuilder: ConnectionManager not found")
	if not ui_manager: printerr("BridgeBuilder: UIManager not found")

	build_timer.wait_time = build_delay
	build_timer.timeout.connect(_on_BuildTimer_timeout)
	get_tree().get_root().mouse_exited.connect(_on_mouse_exited)

# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if not build_mode: return
	if event is InputEventMouseMotion: _handle_mouse_motion(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_handle_left_mouse_release(event)

func _handle_mouse_motion(event: InputEventMouseMotion):
	var new_grid_pos = grid_manager.world_to_grid(event.position)
	if current_path.is_empty() or new_grid_pos == current_path.back():
		return

	var last_grid_pos = current_path.back()
	var dx = abs(new_grid_pos.x - last_grid_pos.x)
	var dy = abs(new_grid_pos.y - last_grid_pos.y)

	# --- FIX: Only allow cardinal (non-diagonal) drawing ---
	# A move is cardinal if it's one step on one axis and zero on the other.
	if (dx + dy) == 1:
		_add_point_to_path(new_grid_pos)
	# If the mouse jumped several cells, interpolate cardinally.
	elif (dx > 0 or dy > 0):
		_interpolate_path_cardinal(last_grid_pos, new_grid_pos)
	
	_update_preview()


func _handle_left_mouse_release(event: InputEventMouseButton):
	var grid_pos = grid_manager.world_to_grid(event.position)
	var target_node = grid_manager.get_grid_object(grid_pos)
	if target_node is Pipe and target_node != start_pipe:
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
		if abs(diff.x) > abs(diff.y):
			step.x = sign(diff.x)
		else:
			step.y = sign(diff.y)
		current_pos += step
		_add_point_to_path(current_pos)

# --- Build Process ---

func start_building(pipe: Pipe, pos: Vector2i):
	if build_mode: return
	build_mode = true
	start_pipe = pipe
	start_pos = pos
	current_path = [pos]
	preview_line.visible = true
	grid_manager.show_grid()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func _finish_building(end_pipe: Pipe, end_pos: Vector2i):
	if not current_path.has(end_pos): _add_point_to_path(end_pos)
	
	# 检查路径和管道类型
	var path_to_check = current_path.slice(1, current_path.size() - 1)
	if not grid_manager.is_grid_available(path_to_check) or start_pipe.pipe_type != end_pipe.pipe_type:
		_cancel_building()
		return
		
	# 检查资源成本
	var total_cost = current_path.size() * bridge_segment_cost
	if not GameManager.spend_resource_value(total_cost):
		print("建造失败: 资源不足!")
		# 在这里可以添加一个UI提示，比如在屏幕上显示"资源不足"
		_cancel_building()
		return
	
	# --- Setup for Sequential Build ---
	sequential_build_path = current_path
	path_connection_set.clear()
	for pos in sequential_build_path: path_connection_set[pos] = true
	
	if sequential_build_path.size() >= 2:
		var start_dir = sequential_build_path[0] - sequential_build_path[1]
		path_connection_set[sequential_build_path[0] + start_dir] = true
		var end_dir = sequential_build_path.back() - sequential_build_path[sequential_build_path.size() - 2]
		path_connection_set[sequential_build_path.back() + end_dir] = true

	front_build_index = 0
	back_build_index = sequential_build_path.size() - 1
	
	connection_manager.add_connection(start_pipe, end_pipe)
	start_pipe.mark_pipe_as_used()
	end_pipe.mark_pipe_as_used()
	
	_reset_build_mode(false)
	build_timer.start()

func _on_BuildTimer_timeout():
	var build_finished = false
	if front_build_index <= back_build_index:
		_create_single_bridge_segment(sequential_build_path[front_build_index])
		front_build_index += 1
	
	if front_build_index -1 != back_build_index:
		if back_build_index >= front_build_index:
			_create_single_bridge_segment(sequential_build_path[back_build_index])
			back_build_index -= 1
	
	if front_build_index > back_build_index:
		build_finished = true

	if build_finished:
		build_timer.stop()
		sequential_build_path.clear()
		path_connection_set.clear()
		print("--- 桥梁建造完毕 ---")

func _create_single_bridge_segment(grid_pos: Vector2i):
	var neighbors = {
		"north": path_connection_set.has(grid_pos + Vector2i.UP),
		"south": path_connection_set.has(grid_pos + Vector2i.DOWN),
		"east": path_connection_set.has(grid_pos + Vector2i.RIGHT),
		"west": path_connection_set.has(grid_pos + Vector2i.LEFT)
	}
	
	var bridge_segment = BridgeScene.instantiate()
	bridges_container.add_child(bridge_segment)
	bridge_segment.global_position = grid_manager.grid_to_world(grid_pos)
	
	bridge_segment.bridge_selected.connect(ui_manager._on_bridge_selected)
	bridge_segment.setup_segment(grid_pos)
	bridge_segment.setup_bridge_tile(neighbors)

func _cancel_building():
	_reset_build_mode(true)

func _reset_build_mode(clear_path: bool):
	build_mode = false
	start_pipe = null
	if clear_path: current_path.clear()
	preview_line.clear_points()
	preview_line.visible = false
	grid_manager.hide_grid()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_mouse_exited():
	if build_mode: _cancel_building()

func _update_preview():
	preview_line.clear_points()
	if current_path.size() < 2: return
	for grid_pos in current_path:
		preview_line.add_point(grid_manager.grid_to_world(grid_pos))
