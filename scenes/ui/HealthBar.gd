extends ProgressBar

# 当血条值更新时，使用Tween动画平滑过渡

# 血条动画的持续时间
@export var tween_duration: float = 0.5
# 血条动画使用的过渡类型
@export var tween_trans: Tween.TransitionType = Tween.TRANS_SINE
# 血条动画使用的缓动类型
@export var tween_ease: Tween.EaseType = Tween.EASE_OUT

var _tween: Tween

# 当血条的目标值和当前显示值不同时，存储目标值
var _target_value: float


func _ready() -> void:
	# 初始化时，目标值就是当前值
	_target_value = value
	# 以下代码被注释掉，因为它与 tween 动画冲突。
	# tween 在每一帧更新 value 属性，会触发 value_changed 信号，
	# 导致 _on_value_changed 被调用，它会创建一个新的、冲突的 tween，
	# 形成一个循环，阻止血条正常更新。
	# 本节点的正确用法是调用 update_health() 函数。
	# value_changed.connect(_on_value_changed)


# 当血条的value属性被外部直接改变时调用
# (已注释掉，因为它与tween动画冲突)
#func _on_value_changed(new_value: float) -> void:
#	# 如果外部直接设置的值不等于当前动画的目标值，则更新动画
#	if not is_equal_approx(new_value, _target_value):
#		update_health(new_value, max_value)


# 提供给外部调用的接口，用于更新血条
# health: 当前生命值
# max_health: 最大生命值
# animate: 是否使用动画
func update_health(health: float, new_max_health: float = -1, animate: bool = true) -> void:
	# 如果传入了新的最大生命值，则更新
	if new_max_health > 0:
		max_value = new_max_health

	# 立即更新可见性：只要血量不是满的，就应该显示
	visible = health < max_value
	
	# 更新目标值
	_target_value = health

	# 如果已经有一个动画正在运行，先杀掉它
	if _tween and _tween.is_valid():
		_tween.kill()

	# 根据 animate 参数决定是立即设置值还是播放动画
	if animate:
		# 创建一个新的Tween
		_tween = create_tween()
		# 设置动画：在tween_duration时间内，将value平滑地变成_target_value
		_tween.tween_property(self, "value", _target_value, tween_duration).set_trans(tween_trans).set_ease(tween_ease)
	else:
		# 不使用动画，直接设置最终值
		value = _target_value
