extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D

enum PipeType {
	LIFE,
	SUPPLY,
	SIGNAL
}

@export var pipe_type : PipeType
## 每秒传输的资源量
@export var resource_per_second: float = 1.0

var is_connected_local: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


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

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("鼠标左键按下")
		else:
			print("鼠标左键释放")
