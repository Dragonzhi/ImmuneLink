extends Area2D
class_name CalmingShot

var speed: float = 200.0
var damage: float = 10.0
var target: Node2D = null

@onready var lifetime_timer: Timer = $LifetimeTimer

func launch(shot_target: Node2D, shot_damage: float):
	target = shot_target
	damage = shot_damage

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	lifetime_timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		# 如果目标无效（例如，已被摧毁），则子弹也应该消失
		queue_free()
		return
	
	# 简单的追踪逻辑
	var direction = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D):
	# 检查碰撞的是否是敌人的伤害区域
	if area.get_parent() is BaseEnemy:
		var enemy: BaseEnemy = area.get_parent()
		if enemy == target: # 确保只击中预定目标
			enemy.take_damage(damage)
			queue_free() # 击中后消失
