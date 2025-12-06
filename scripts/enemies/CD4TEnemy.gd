# CD4TEnemy.gd
class_name CD4TEnemy
extends BaseEnemy

@export var buff_strength_multiplier: float = 1.5 # 速度Buff的强度，例如1.5表示速度提升50%
@export var buff_range: float = 24.0 # Buff光环的范围半径
@export var buff_interval: float = 3.0 # Buff脉冲的间隔时间 (秒)
@export var buff_duration: float = 2.0 # 施加给其他敌人的Buff持续时间 (秒)

@onready var buff_aura: Area2D = $BuffAura
@onready var buff_collision_shape: CollisionShape2D = $BuffAura/BuffCollisionShape2D
@onready var _sprite_node: Sprite2D = $Sprite2D # 获取Sprite2D节点用于动画

var _buff_pulse_timer: Timer

func _ready() -> void:
	super._ready() # 调用BaseEnemy的_ready()函数

	# 设置Buff光环的范围
	if buff_collision_shape and buff_collision_shape.shape is CircleShape2D:
		(buff_collision_shape.shape as CircleShape2D).radius = buff_range
	else:
		printerr("CD4TEnemy: BuffAura/BuffCollisionShape2D is not a CircleShape2D or not found!")
	
	# 设置并启动Buff脉冲计时器
	_buff_pulse_timer = Timer.new()
	_buff_pulse_timer.wait_time = buff_interval
	_buff_pulse_timer.one_shot = false
	_buff_pulse_timer.autostart = true
	_buff_pulse_timer.timeout.connect(_on_buff_pulse_timer_timeout)
	add_child(_buff_pulse_timer)

## --- 新增Buff脉冲逻辑 ---
func _on_buff_pulse_timer_timeout() -> void:
	_play_buff_animation()
	
	# 获取光环范围内所有敌人，并给它们施加Buff
	var overlapping_bodies = buff_aura.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is BaseEnemy and body != self: # 确保是其他敌人且不是自己
			(body as BaseEnemy).apply_buff("speed", buff_strength_multiplier, buff_duration)
			# print("CD4TEnemy: Buffed %s" % body.name)

func _play_buff_animation() -> void:
	if not is_instance_valid(_sprite_node): return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC) # Q弹效果
	tween.set_ease(Tween.EASE_OUT)
	
	# 缩放动画：先压扁再拉长，然后恢复
	# Y轴先缩小，X轴先放大
	tween.tween_property(_sprite_node, "scale", Vector2(0.13, 0.18), 0.2)
	tween.tween_callback(Callable(self, "_play_buff_vfx"))
	tween.tween_property(_sprite_node, "scale", Vector2(0.17, 0.13), 0.2)
	tween.tween_property(_sprite_node, "scale", Vector2(0.15, 0.15), 0.4)
	
func _play_buff_vfx() -> void:
	VFXManager.play_effect("CD4T_buff", global_position)
