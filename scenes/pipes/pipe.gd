extends Node2D
class_name Pipe

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var connection_points: Node2D = $ConnectionPoints

enum PipeType {
	LIFE,
	SUPPLY,
	SIGNAL
}

@export var pipe_type : PipeType
'''
* 朝右： (-1, 0)
* 朝下： (0, -1)
* 朝左： (1, 0)
* 朝上： (0, 1)
'''
@export var direction: Vector2i = Vector2i.ZERO
## 每秒传输的资源量
@export var resource_per_second: float = 1.0

var is_connected_local: bool = false
var grid_manager: GridManager
var bridge_builder: BridgeBuilder

# 标记整个管道是否已被用于连接
var is_pipe_used: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 获取单例引用
	grid_manager = get_node("/root/GridManager")
	bridge_builder = get_node("/root/Main/BridgeBuilder")
	if not grid_manager:
		printerr("错误: 找不到GridManager")
	if not bridge_builder:
		printerr("错误: 找不到BridgeBuilder")
	# 在GridManager中注册所有连接点的位置
	if connection_points:
		for point in connection_points.get_children():
			if point is Marker2D:
				var grid_pos = grid_manager.world_to_grid(point.global_position)
				grid_manager.set_grid_occupied(grid_pos, self)
	match pipe_type:
		PipeType.LIFE:
			self.modulate = Color(1,0.1,0)
		PipeType.SUPPLY:
			self.modulate = Color(0,0.5,1)
		PipeType.SIGNAL:
			self.modulate = Color.YELLOW

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	pass

func on_connected():
	is_connected_local = true
	# 根据管道类型触发不同效果
	match pipe_type:
		PipeType.LIFE:
			pass
			#GameManager.add_health_flow(resource_per_second)
		PipeType.SUPPLY:
			pass
			#ResourceManager.add_income(resource_per_second)
		PipeType.SIGNAL:
			pass
			#SignalManager.activate_signal_zone(self)

# 将整个管道标记为已使用
func mark_pipe_as_used():
	is_pipe_used = true
	# 可选：改变已使用管道的外观，比如颜色变灰
	sprite_2d.modulate = Color.GRAY

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 检查管道是否已被使用
			if is_pipe_used:
				print("管道已被使用!")
				return
				
			# 找到最近的连接点
			var closest_point = _get_closest_connection_point(event.global_position)
			if closest_point:
				var start_grid_pos = grid_manager.world_to_grid(closest_point.global_position)
				# 通知BridgeBuilder开始建造
				if bridge_builder:
					bridge_builder.start_building(self, start_grid_pos, direction)
		else:
			# 释放鼠标按钮的逻辑（如果需要的话）现在由BridgeBuilder处理
			pass

# 找到离给定世界坐标最近的连接点
func _get_closest_connection_point(pos: Vector2) -> Marker2D:
	var closest_point: Marker2D = null
	var min_dist_sq = INF
	
	if connection_points:
		for point in connection_points.get_children():
			if point is Marker2D:
				var dist_sq = pos.distance_squared_to(point.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_point = point
	
	return closest_point

# 当鼠标进入管道区域时
func _on_area_2d_mouse_entered() -> void:
	# 鼠标悬停效果
	sprite_2d.modulate = Color.LIGHT_BLUE

# 当鼠标离开管道区域时
func _on_area_2d_mouse_exited() -> void:
	# 恢复原始颜色
	sprite_2d.modulate = Color.WHITE
