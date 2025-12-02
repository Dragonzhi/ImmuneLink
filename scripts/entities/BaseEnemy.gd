extends CharacterBody2D
class_name BaseEnemy

const HitEffectScene = preload("res://scenes/effects/HitEffect.tscn")

# 定义状态枚举，用于管理敌人行为
enum State { MOVING, ATTACKING }

@export var max_hp: float = 100.0
@export var move_speed: float = 50.0
@export var damage: float = 10.0 # 对桥梁的伤害
@export var attack_rate: float = 1.0 # 每秒攻击次数
@export_group("Wiggle Movement")
@export var sine_frequency: float = 0.1 # 摆动频率
@export var sine_amplitude: float = 20.0 # 摆动幅度

var current_hp: float
var current_state: State = State.MOVING
var target_bridge: Bridge = null
var is_dying: bool = false
var is_spawning: bool = true
var spawner: Node2D # 用于存储生成点的引用

# 路径相关变量
var path_node: Path2D
var distance_along_path: float = 0.0

signal path_finished(enemy: BaseEnemy)

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBarContainer/HealthBar
@onready var attack_timer: Timer = $AttackTimer
@onready var path_check_timer: Timer = $PathCheckTimer

func _ready() -> void:
	current_hp = max_hp
	_update_health_bar()
	_play_spawn_animation()
	
	# 设置攻击计时器
	attack_timer.one_shot = false
	attack_timer.wait_time = 1.0 / attack_rate
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# 设置路径检查计时器
	path_check_timer.one_shot = false
	path_check_timer.wait_time = randf_range(3.0, 5.0) # 3到5秒随机检查一次
	path_check_timer.timeout.connect(_on_path_check_timer_timeout)
	path_check_timer.start()

func _physics_process(delta: float) -> void:
	if is_spawning or is_dying:
		velocity = Vector2.ZERO # 确保在生成或死亡时停止移动
		move_and_slide()
		return

	match current_state:
		State.MOVING:
			_execute_movement(delta)
		State.ATTACKING:
			_execute_attack(delta)
	
	# 保证血条始终是水平的
	if is_instance_valid(health_bar):
		health_bar.get_parent().global_rotation = 0


# --- 状态处理 ---

func _execute_movement(delta: float):
	# 如果没有路径，就原地待命
	if not is_instance_valid(path_node) or not is_instance_valid(path_node.curve):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var path_length = path_node.curve.get_baked_length()
	# 如果路径长度为0，则不进行任何移动
	if path_length <= 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 使用fmod实现路径循环
	distance_along_path = fmod(distance_along_path + move_speed * delta, path_length)

	# 在路径上采样一个中心目标点
	var target_point_local = path_node.curve.sample_baked(distance_along_path, true)
	var target_point_global = path_node.to_global(target_point_local)

	# --- 正弦波移动逻辑 ---
	var path_direction = (target_point_global - global_position).normalized()
	# 计算垂直于路径方向的向量
	var perpendicular_dir = path_direction.orthogonal()
	# 基于沿路径的距离计算正弦偏移
	var offset = sin(distance_along_path * sine_frequency) * sine_amplitude
	# 计算最终的、带有偏移的目标点
	var final_target = target_point_global + perpendicular_dir * offset
	# --- 正弦波逻辑结束 ---

	# 计算朝向最终目标点的方向和速度
	var direction = (final_target - global_position).normalized()
	velocity = direction * move_speed

	# 移动并检测碰撞
	move_and_slide()
	
	# 检查碰撞
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			if collider is Bridge and collider.is_in_group("bridges"):
				# 撞到桥了，切换到攻击状态
				_enter_attack_state(collider)
				return # 本帧不再继续移动逻辑


func _execute_attack(delta: float):
	# 攻击状态下，停止移动
	velocity = Vector2.ZERO
	move_and_slide()

	# 检查目标桥梁是否还存在或者已经被摧毁
	if not is_instance_valid(target_bridge) or target_bridge.is_destroyed:
		_enter_move_state()


func _enter_attack_state(bridge: Bridge):
	# print("敌人 %s 开始攻击桥梁 %s" % [self.name, bridge.name])
	current_state = State.ATTACKING
	target_bridge = bridge
	attack_timer.start()

func _enter_move_state():
	# print("敌人 %s 停止攻击，继续移动" % self.name)
	current_state = State.MOVING
	target_bridge = null
	attack_timer.stop()


# --- 外部调用和信号处理 ---

# 新的设置路径方法
func set_path(new_path_node: Path2D) -> void:
	if not is_instance_valid(new_path_node):
		path_node = null
		return
	path_node = new_path_node
	distance_along_path = 0.0
	_enter_move_state()

func _on_attack_timer_timeout():
	if current_state == State.ATTACKING and is_instance_valid(target_bridge):
		target_bridge.take_damage(damage)

func _on_path_check_timer_timeout():
	print("--- 敌人路径检查 ---")
	# 检查spawner是否存在且有获取路径的方法
	if not is_instance_valid(spawner) or not spawner.has_method("get_active_path"):
		print("检查失败: 生成点无效或没有 get_active_path 方法。")
		return
	
	print("生成点有效。")
	var spawner_path = spawner.get_active_path()
	
	print("自己的路径: ", path_node.name if is_instance_valid(path_node) else "null")
	print("生成点的路径: ", spawner_path.name if is_instance_valid(spawner_path) else "null")
	
	# 如果spawner的当前路径和自己的不一样，就切换过去
	if is_instance_valid(spawner_path) and spawner_path != path_node:
		print(">>>>> 检测到新路径，正在切换...")
		set_path(spawner_path)
	else:
		print("路径相同，无需切换。")
	print("--------------------")


# --- 原有的辅助函数 (部分保留和适配) ---

func take_damage(amount: float):
	if is_dying: return

	current_hp -= amount
	_update_health_bar()
	
	var hit_effect = HitEffectScene.instantiate()
	get_tree().get_root().get_node("Main/Foreground/Particles").add_child(hit_effect)
	hit_effect.global_position = global_position
	hit_effect.set_emitting(true)
	
	if current_hp <= 0:
		start_death_sequence()

func start_death_sequence():
	if is_dying: return
	is_dying = true
	attack_timer.stop() # 死亡时停止攻击
	
	if is_instance_valid(health_bar):
		health_bar.hide()
	
	# 禁用碰撞
	get_node("CollisionShape2D").set_deferred("disabled", true)
	get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
	
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 360, 0.5)
	tween.finished.connect(queue_free)

func _update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return
	var health_percent = (current_hp / max_hp) * 100.0
	health_bar.value = health_percent
	if current_hp < max_hp:
		health_bar.show()
	else:
		health_bar.hide()

func _play_spawn_animation():
	scale = Vector2.ZERO
	if is_instance_valid(sprite):
		sprite.modulate.a = 0.0

	var spawn_tween = create_tween()
	spawn_tween.set_parallel()
	spawn_tween.set_ease(Tween.EASE_OUT)
	spawn_tween.set_trans(Tween.TRANS_SINE)

	spawn_tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	if is_instance_valid(sprite):
		spawn_tween.tween_property(sprite, "modulate:a", 1.0, 0.4)

	spawn_tween.finished.connect(func(): is_spawning = false)

# 物理碰撞现在处理桥梁交互，这里可以留空或用于其他逻辑
func _on_area_2d_area_entered(area: Area2D) -> void:
	pass
