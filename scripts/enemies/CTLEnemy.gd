extends BaseEnemy

# "狂战士" 效果：被攻击后会短暂提升攻击力和移动速度

@export_group("CTL细胞特性")
# 攻击力提升的倍率
@export var damage_boost_multiplier: float = 2.0
# 移动速度提升的倍率
@export var speed_boost_multiplier: float = 1.5
# 效果持续时间（秒）
@export var boost_duration: float = 3.0
# 狂暴状态颜色
@export var boost_color: Color = Color(1.8, 0.8, 0.8)

# -- 节点引用 --
# 用于重置状态的计时器 
@onready var _boost_timer: Timer = $BoostTimer
# 狂暴效果粒子 
@onready var _boost_particles: GPUParticles2D = $BoostParticles


# -- 内部变量 --
# 用于保存原始攻击力
var _original_damage: float
# 标记当前是否处于狂暴状态
var _is_boosted: bool = false
# 用于缓动动画
var _tween: Tween


func _ready() -> void:
	DebugManager.register_category("CTLEnemy", false)
	# 首先调用父类的_ready方法，以完成所有基础初始化（包括数值随机化）
	super._ready()
	
	# 在父类初始化后，保存随机化之后的原始攻击力
	# _original_move_speed 已经在父类中保存好了
	_original_damage = damage
	
	# 配置计时器
	_boost_timer.wait_time = boost_duration
	_boost_timer.one_shot = true
	# 确保信号只连接一次
	if not _boost_timer.timeout.is_connected(_on_boost_timer_timeout):
		_boost_timer.timeout.connect(_on_boost_timer_timeout)


# 重写 take_damage 函数
func take_damage(amount: float) -> void:
	# 如果已经死亡，则不执行任何操作
	if is_dying:
		return
		
	# 首先，调用父类的 take_damage 方法来处理伤害计算和血条更新
	super.take_damage(amount)
	
	# 在受到伤害后，触发狂暴效果（前提是还没死）
	if not is_dying:
		_trigger_boost()


# 触发或刷新增益效果
func _trigger_boost() -> void:
	# 播放粒子效果
	_boost_particles.emitting = true
	
	# 播放颜色动画
	_animate_color(boost_color)
	
	if not _is_boosted:
		_is_boosted = true
		
		# 提升属性
		var old_damage = damage
		var old_speed = move_speed
		damage *= damage_boost_multiplier
		move_speed *= speed_boost_multiplier
		
		# 播放音效
		SoundManager.play_sfx("phaserUp1")
		
		DebugManager.dprint(
			"CTLEnemy", 
			"CTL细胞 %s 进入狂暴状态！攻击力: %.1f -> %.1f, 速度: %.1f -> %.1f" 
			% [self.name, old_damage, damage, old_speed, move_speed]
		)

	# 无论之前是否处于狂暴状态，都重置计时器
	_boost_timer.start()
	DebugManager.dprint("CTLEnemy", "CTL细胞 %s 狂暴计时器已重置。" % self.name)


# 当计时器超时时调用此方法
func _on_boost_timer_timeout() -> void:
	if _is_boosted:
		DebugManager.dprint("CTLEnemy", "CTL细胞 %s 狂暴效果结束。" % self.name)
		
		# 将属性恢复到原始值
		damage = _original_damage
		move_speed = _original_move_speed # _original_move_speed 是在 BaseEnemy 中定义的
		
		# 停止粒子效果
		_boost_particles.emitting = false
		
		# 恢复颜色
		_animate_color(Color.WHITE)
		
		_is_boosted = false

# 辅助函数：用于播放颜色缓动动画
func _animate_color(target_color: Color) -> void:
	# 如果有正在播放的动画，先杀掉，防止冲突
	if is_instance_valid(_tween):
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	# sprite 变量继承自 BaseEnemy
	_tween.tween_property(sprite, "modulate", target_color, 0.2)
