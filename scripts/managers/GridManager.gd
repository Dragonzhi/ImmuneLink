# GridManager.gd
extends Node2D
#class_name GridManager

@export var grid_size: int = 16  # 每个网格的像素大小
@export var grid_width: int = 40 # 网格宽度（格子数）
@export var grid_height: int = 40 # 网格高度（格子数）

# 用于存储被占用的网格单元及其对应的节点
var occupied_cells = {}

# 网格线可视化
var grid_lines: Array[Line2D] = []
var is_grid_visible: bool = false
var active_tween: Tween

const GRID_COLOR = Color(1, 1, 1, 0.2)
const FADE_DURATION = 0.25
const OCCUPIED_COLOR = Color(1, 0, 0, 0.3)

func _ready():
	create_grid_visual()
	# Initially hide lines without fading
	for line in grid_lines:
		line.visible = false

func _draw():
	# Draw a rectangle over each occupied cell, only if the grid is visible
	if is_grid_visible:
		for grid_pos in occupied_cells.keys():
			var rect_pos = grid_to_world(grid_pos) - Vector2(grid_size / 2, grid_size / 2)
			var rect_size = Vector2(grid_size, grid_size)
			draw_rect(Rect2(rect_pos, rect_size), OCCUPIED_COLOR)

func create_grid_visual():
	# 创建垂直线
	for x in range(grid_width + 1):
		var line = Line2D.new()
		line.width = 2
		line.default_color = Color.TRANSPARENT # Start transparent
		line.add_point(Vector2(x * grid_size, 0))
		line.add_point(Vector2(x * grid_size, grid_height * grid_size))
		add_child(line)
		grid_lines.append(line)
	
	# 创建水平线
	for y in range(grid_height + 1):
		var line = Line2D.new()
		line.width = 2
		line.default_color = Color.TRANSPARENT # Start transparent
		line.add_point(Vector2(0, y * grid_size))
		line.add_point(Vector2(grid_width * grid_size, y * grid_size))
		add_child(line)
		grid_lines.append(line)

func show_grid():
	if active_tween:
		active_tween.kill()
	
	is_grid_visible = true
	active_tween = create_tween().set_parallel()

	for line in grid_lines:
		line.visible = true
		active_tween.tween_property(line, "default_color", GRID_COLOR, FADE_DURATION)
	queue_redraw()

func hide_grid():
	if active_tween:
		active_tween.kill()

	is_grid_visible = false
	active_tween = create_tween().set_parallel()
	
	var transparent_color = Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, 0)
	for line in grid_lines:
		active_tween.tween_property(line, "default_color", transparent_color, FADE_DURATION)

	# When the fade-out is complete, hide the nodes
	active_tween.finished.connect(_on_hide_tween_finished)
	queue_redraw()

func _on_hide_tween_finished():
	for line in grid_lines:
		line.visible = false

func toggle_grid():
	if is_grid_visible:
		hide_grid()
	else:
		show_grid()

# 将节点设置到指定的网格位置
func set_grid_occupied(grid_pos: Vector2i, node: Node2D):
	occupied_cells[grid_pos] = node
	queue_redraw()

# 检查给定的网格路径是否可用
func is_grid_available(grid_path: Array) -> bool:
	for grid_pos in grid_path:
		if occupied_cells.has(grid_pos):
			return false
	return true

# 获取指定网格位置的节点对象
func get_grid_object(grid_pos: Vector2i) -> Node:
	if occupied_cells.has(grid_pos):
		return occupied_cells[grid_pos]
	return null

# 检查坐标是否在网格范围内
func is_within_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height

# 世界坐标转换为网格坐标
func world_to_grid(world_pos: Vector2) -> Vector2i:
	# 通过减去本节点的全局位置，我们获得相对于本节点左上角的坐标，从而避免了父节点位移带来的问题。
	var relative_pos = world_pos - global_position
	return Vector2i(
		floor(relative_pos.x / grid_size),
		floor(relative_pos.y / grid_size)
	)

# 网格坐标转换为世界坐标
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var local_pos = Vector2(
		grid_pos.x * grid_size + grid_size / 2,
		grid_pos.y * grid_size + grid_size / 2
	)
	return to_global(local_pos)

# --- Bridge Status Tracking ---
var _destroyed_bridge_cells: Dictionary = {}

func set_bridge_status(grid_pos: Vector2i, is_destroyed: bool):
	"""
	Called by Bridge segments to report their status.
	"""
	if is_destroyed:
		_destroyed_bridge_cells[grid_pos] = true
	else:
		if _destroyed_bridge_cells.has(grid_pos):
			_destroyed_bridge_cells.erase(grid_pos)
	print("GridManager: Status updated for %s. Destroyed cells are now: %s" % [grid_pos, _destroyed_bridge_cells.keys()])

func is_path_intact(path_points: Array[Vector2i]) -> bool:
	"""
	Checks if a given path of grid points contains any destroyed bridges.
	"""
	for point in path_points:
		if _destroyed_bridge_cells.has(point):
			return false # Path is broken
	return true # Path is intact

func get_occupied_cells_debug() -> Dictionary:
	return occupied_cells
