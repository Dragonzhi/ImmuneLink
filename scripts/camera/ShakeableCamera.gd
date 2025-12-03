extends Camera2D
class_name ShakeableCamera

# 用于控制震动的变量
var _shake_amplitude: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

# PRNG for random numbers
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	self.position = Vector2i(192,108)

func _process(delta: float) -> void:
	# 检查震动计时器
	if _shake_timer > 0:
		_shake_timer -= delta
		if _shake_timer <= 0:
			# 震动结束，重置相机偏移
			offset = Vector2.ZERO
		else:
			# 计算当前的震动幅度（随时间衰减）
			var current_amplitude = _shake_amplitude * (_shake_timer / _shake_duration)
			# 生成一个随机的二维方向向量
			var random_offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
			# 应用偏移
			offset = random_offset.normalized() * current_amplitude
	else:
		offset = Vector2.ZERO

## public方法，用于从外部触发震动
## amplitude: 震动的幅度（像素）
## duration: 震动的持续时间（秒）
func shake(amplitude: float, duration: float) -> void:
	_shake_amplitude = amplitude
	_shake_duration = duration
	_shake_timer = duration
