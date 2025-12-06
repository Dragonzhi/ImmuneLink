# CD4TEnemy.gd
class_name CD4TEnemy
extends BaseEnemy

@export var buff_strength_multiplier: float = 1.5 # 速度Buff的强度，例如1.5表示速度提升50%
@export var buff_range: float = 24.0 # Buff光环的范围半径

@onready var buff_aura: Area2D = $BuffAura
@onready var buff_collision_shape: CollisionShape2D = $BuffAura/BuffCollisionShape2D


func _ready() -> void:
	super._ready() # 调用BaseEnemy的_ready()函数

	# 设置Buff光环的范围
	if buff_collision_shape and buff_collision_shape.shape is CircleShape2D:
		(buff_collision_shape.shape as CircleShape2D).radius = buff_range
	else:
		printerr("CD4TEnemy: BuffAura/BuffCollisionShape2D is not a CircleShape2D or not found!")
	
func _on_buff_aura_body_entered(body: Node2D) -> void:
	if body is BaseEnemy and body != self: # 确保是其他敌人且不是自己
		(body as BaseEnemy).apply_speed_buff(buff_strength_multiplier)
		# print("CD4TEnemy: %s entered aura, buffed %s" % [body.name, body.move_speed])


func _on_buff_aura_body_exited(body: Node2D) -> void:
	if body is BaseEnemy and body != self: # 确保是其他敌人且不是自己
		(body as BaseEnemy).remove_speed_buff()
		# print("CD4TEnemy: %s exited aura, buff removed" % [body.name])
