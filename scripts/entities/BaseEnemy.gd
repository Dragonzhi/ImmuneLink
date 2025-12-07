extends CharacterBody2D
class_name BaseEnemy

# 定义状态枚举，用于管理敌人行为
enum State { MOVING, ATTACKING }

@export var max_hp: float = 100.0
@export var move_speed: float = 50.0
@export var damage: float = 10.0 # 对桥梁的伤害
@export var attack_rate: float = 1.0 # 每秒攻击次数
@export_group("Wiggle Movement")
@export var sine_frequency: float = 0.1 # 摆动频率
@export var sine_amplitude: float = 20.0 # 摆动幅度
@export_group("Path Switching")
@export var check_path_on_loop_only: bool = true # 是否仅在循环回到起点时才检查路径切换
@export_group("UI")
@export var health_bar: ProgressBar
@export_group("Separation")
@export var separation_strength: float = 50.0 # 与其他敌人分离的推力强度
@onready var separation_detector: Area2D = $SeparationDetector


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
@onready var attack_timer: Timer = $AttackTimer
@onready var nk_buff_timer: Timer = $NKBuffTimer # 获取场景中的计时器节点

var _original_move_speed: float
var _active_buffs: Dictionary = {} # Stores active buffs, key: buff_type, value: {timer, original_value, current_multiplier}

func _ready() -> void:
	DebugManager.register_category("BaseEnemy", false)
	# 应用个体数值浮动
	var variation_factor = randf_range(0.9, 1.1) # +/- 10% 浮动
	max_hp *= variation_factor
	move_speed *= variation_factor
	damage *= variation_factor
	
	# 确保数值不会过低
	max_hp = max(1.0, max_hp)
	move_speed = max(1.0, move_speed)
	damage = max(0.0, damage) 
	
	# 关键：在这里记录下经过随机浮动后的原始速度，用于Buff/Debuff系统
	_original_move_speed = move_speed
	
	current_hp = max_hp
	# 初始化血条，传递当前生命值和最大生命值，并且不播放动画
	health_bar.update_health(current_hp, max_hp, false)
	_play_spawn_animation()
	# 设置攻击计时器
	attack_timer.one_shot = false
	attack_timer.wait_time = 1.0 / attack_rate
	attack_timer.timeout.connect(_on_attack_timer_timeout)

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

func _get_separation_vector() -> Vector2:
	# 从分离探测器获取所有重叠的物体（即邻近的敌人）
	var neighbors = separation_detector.get_overlapping_bodies()
	var push_vector = Vector2.ZERO
	
	# 如果没有邻居，则不产生任何推力
	if neighbors.is_empty():
		return Vector2.ZERO
		
	# 遍历所有邻居，计算一个总的推开方向
	for neighbor in neighbors:
		# 计算一个从邻居指向“我”的向量
		var away_from_neighbor = global_position - neighbor.global_position
		# 累加这个向量，越近的邻居贡献的向量长度越大，推力也越强
		if away_from_neighbor.length_squared() > 0:
			push_vector += away_from_neighbor.normalized() / away_from_neighbor.length()

	# 返回归一化后的推力向量，乘以设定的强度
	if push_vector.length_squared() > 0:
		return push_vector.normalized() * separation_strength
	
	return Vector2.ZERO


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

	var old_distance = distance_along_path
	# 使用fmod实现路径循环
	distance_along_path = fmod(old_distance + move_speed * delta, path_length)

	# --- 路径切换逻辑 ---
	# 当路径循环完成时 (新的距离小于旧的距离)，检查是否需要切换路径
	if check_path_on_loop_only and distance_along_path < old_distance:
		_check_for_path_switch()
		
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

	# 计算朝向最终目标点的路径速度
	var path_velocity = (final_target - global_position).normalized() * move_speed
	
	# 获取分离（推挤）力
	var separation_velocity = _get_separation_vector()
	
	# 将路径速度和分离速度结合
	velocity = path_velocity + separation_velocity
	# 限制最终速度不超过 move_speed，这可以防止抖动
	velocity = velocity.limit_length(move_speed)

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

func _check_for_path_switch():
	# 检查spawner是否存在且有获取路径的方法
	if not is_instance_valid(spawner) or not spawner.has_method("get_active_path"):
		return
	
	var spawner_path = spawner.get_active_path()
	
	# 如果spawner的当前路径和自己的不一样，就切换过去
	if is_instance_valid(spawner_path) and spawner_path != path_node:
		# print(">>>>> 敌人 %s 检测到新路径，正在切换..." % self.name)
		set_path(spawner_path)


# --- 原有的辅助函数 (部分保留和适配) ---

func take_damage(amount: float):
	if is_dying: return

	current_hp -= amount
	health_bar.update_health(current_hp) # 调用血条场景的更新方法
	
	VFXManager.play_effect("hit", global_position)
	
	if current_hp <= 0:
		start_death_sequence()

func start_death_sequence():
	if is_dying: return
	is_dying = true
	
	SoundManager.play_sfx("enemy_die") # 播放死亡音效
	
	# --- 清理所有 Buff 和计时器 ---
	nk_buff_timer.stop()
	
	# 停止并清理所有激活的buff计时器
	for type in _active_buffs.keys():
		var buff_timer: Timer = _active_buffs[type]
		if is_instance_valid(buff_timer):
			buff_timer.stop()
			buff_timer.queue_free()
	_active_buffs.clear()
	
	# 关闭所有粒子效果
	buff_particles.emitting = false
	slow_particles.emitting = false
	# --- 清理逻辑结束 ---
	
	# 播放死亡特效
	#VFXManager.play_effect("enemy_death", global_position)
	
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

func _play_spawn_animation():
	#SoundManager.play_sfx("enemy_show") # 播放敌人出现音效
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


## --- Buff/Debuff 方法 ---
@onready var buff_particles: CPUParticles2D = $BuffParticles
@onready var slow_particles: CPUParticles2D = $SlowParticles # 新增：获取减速粒子节点

func apply_buff(type: String, multiplier: float, duration: float):
	# 统一处理速度相关的buff
	if type == "speed" or type == "nk_slow":
		if _active_buffs.has(type):
			if type == "nk_slow":
				nk_buff_timer.stop() # 如果是nk_slow，则停止移除计时器
			else:
				var buff_timer: Timer = _active_buffs[type] # 其他buff，刷新计时器
				buff_timer.start(duration)
		else:
			# 首次施加此类型Buff
			var old_speed = move_speed
			move_speed *= multiplier
			DebugManager.dprint("BaseEnemy", "Enemy '%s' apply_buff('%s'). Speed changed from %s to %s." % [self.name, type, old_speed, move_speed])
			
			# 根据类型选择不同的粒子效果
			if type == "nk_slow":
				slow_particles.emitting = true # 开启减速粒子
				# 注意：nk_slow 的持续时间由其计时器控制，这里传入的duration被忽略
			else: # "speed"
				buff_particles.emitting = true # 开启加速粒子
				var buff_timer = Timer.new()
				buff_timer.wait_time = duration
				buff_timer.one_shot = true
				buff_timer.timeout.connect(remove_buff.bind(type))
				add_child(buff_timer)
				buff_timer.start()
				_active_buffs[type] = buff_timer
			
			# 无论哪种，都将其记录在_active_buffs中，方便统一管理
			if not _active_buffs.has(type):
				# 对于nk_slow，我们不存储计时器，但仍需标记其为激活状态
				_active_buffs[type] = null 


func remove_buff(type: String):
	DebugManager.dprint("BaseEnemy", "BaseEnemy: Attempting to remove buff '%s'." % type)
	if _active_buffs.has(type):
		
		# 对于非nk_slow的buff，清理其动态创建的计时器
		if type != "nk_slow":
			var buff_timer: Timer = _active_buffs[type]
			if is_instance_valid(buff_timer):
				buff_timer.queue_free()
		
		if type == "speed" or type == "nk_slow":
			# 将速度恢复到被Buff前的原始值
			var old_speed = move_speed
			move_speed = _original_move_speed 
			DebugManager.dprint("BaseEnemy", "BaseEnemy: '%s' remove_buff('%s'). Speed changed from %s to %s." % [self.name, type, old_speed, move_speed])
			
			# 根据类型停止相应的粒子效果
			if type == "nk_slow":
				slow_particles.emitting = false # 关闭减速粒子
			else: # "speed"
				buff_particles.emitting = false # 关闭加速粒子
		
		_active_buffs.erase(type)
	else:
		DebugManager.dprint("BaseEnemy", "BaseEnemy: Buff '%s' not found in _active_buffs." % type)


# 物理碰撞现在处理桥梁交互，这里可以留空或用于其他逻辑
func _on_area_2d_area_entered(area: Area2D) -> void:
	pass


func _on_nk_buff_timer_timeout() -> void:
	DebugManager.dprint("BaseEnemy", "BaseEnemy: NKBuffTimer timeout! Removing nk_slow buff.")
	remove_buff("nk_slow")
