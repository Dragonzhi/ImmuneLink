extends Node2D
class_name Bridge

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

@export var max_health: float = 100.0
@export var current_health: float
@export var defense: float = 10.0

var grid_manager: GridManager
var grid_pos: Vector2i # 存储该桥段在网格中的位置

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	
	grid_manager = get_node("/root/Main/GridManager")
	if not grid_manager:
		printerr("错误: 找不到GridManager")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# 设置桥梁段并将其注册到GridManager
func setup_segment(grid_pos: Vector2i):
	self.grid_pos = grid_pos
	if not grid_manager:
		grid_manager = get_node("/root/Main/GridManager")

	if grid_manager:
		grid_manager.set_grid_occupied(grid_pos, self)
	else:
		printerr("无法注册桥梁段: 找不到GridManager")



func _on_area_2d_mouse_entered() -> void:
	# 鼠标悬浮时改变颜色以提供视觉反馈
	sprite.modulate = Color(0.8, 0.8, 0.5) # 淡黄色


func _on_area_2d_mouse_exited() -> void:
	# 鼠标离开时恢复原始颜色
	sprite.modulate = Color.WHITE


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# 检测鼠标左键点击事件
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("点击了桥梁段，位置: ", grid_pos)
		# 在这里可以添加后续的交互逻辑，例如显示信息、升级、拆除等
		get_viewport().set_input_as_handled() # 阻止事件进一步传播
