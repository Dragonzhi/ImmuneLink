extends PathFollow2D
class_name BaseEnemy

@export var max_hp: float = 100.0 ## 最大生命值/冷静值
@export var current_hp: float = 100.0 ## 当前生命值/冷静值
@export var move_speed: float = 50.0 # 移动速度 (单位/秒)
@export var damage: float = 10.0 # 对桥梁造成的伤害

signal path_finished(enemy: BaseEnemy)

@onready var area_2d: Area2D = $Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_hp = max_hp
	rotates = false
	
# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var path_node = get_parent()
	if not path_node is Path2D:
# 如果尚未附加到 Path2D，则不执行任何操作。
		return
	
	var path_curve: Curve2D = path_node.curve
	if not path_curve:
		# 如果未设置曲线，则不执行任何操作。
		return

	var curve_length: float = path_curve.get_baked_length()
	var distance_to_move: float = move_speed * delta

	# 计算新的进度。
	var new_progress: float = progress + distance_to_move

	# 检查新进度是否会超出曲线长度。
	if new_progress >= curve_length:
		progress = curve_length
		emit_signal("path_finished", self)
		queue_free() # 目前，当敌人到达终点时直接删除。
	else:
		progress = new_progress

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.owner is Bridge:
		var bridge: Bridge = area.owner
		bridge.take_damage(damage)

func take_damage(amount: float):
	current_hp -= amount
	print("敌人受到 %s 点镇静效果, 剩余冷静值: %s" % [amount, current_hp])
	if current_hp <= 0:
		print("敌人已被完全镇静！")
		queue_free()
