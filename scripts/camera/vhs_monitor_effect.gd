extends CanvasLayer
# 该脚本应附加到一个覆盖整个屏幕的ColorRect节点上。
# 并且，该ColorRect节点的Material属性应被设置为一个ShaderMaterial，
# 其中Shader为 res://assets/shader/vhs_crt_material.gdshader。

#class_name VHSMonitorEffect
@onready var color_rect: ColorRect = $ColorRect

@export var show_debug_buttons: bool = false # 控制是否显示调试按钮

# --- 内部变量 ---
var _shader_material: ShaderMaterial
var _active_tween: Tween

# 存储各效果的默认值，以便在效果结束后恢复
var _default_distort_intensity: float = 0.05
var _default_noise_opacity: float = 0.4
var _default_static_noise_intensity: float = 0.06
var _default_aberration: float = 0.03
var _default_roll_speed: float = 8.0

func _ready() -> void:
	# 确保此节点上有一个ShaderMaterial
	if color_rect.material is ShaderMaterial:
		_shader_material = color_rect.material as ShaderMaterial
		# 保存初始值（如果它们在编辑器中被修改过）
		_default_distort_intensity = _shader_material.get_shader_parameter("distort_intensity")
		_default_noise_opacity = _shader_material.get_shader_parameter("noise_opacity")
		_default_static_noise_intensity = _shader_material.get_shader_parameter("static_noise_intensity")
		_default_aberration = _shader_material.get_shader_parameter("aberration")
		_default_roll_speed = _shader_material.get_shader_parameter("roll_speed")
	else:
		printerr("VHSMonitorEffect.gd: 必须将此脚本附加到一个带有ShaderMaterial的节点上！")
		set_process(false) # 禁用脚本以防出错
		return # 提前返回，因为后续代码会失败

	# --- 连接预览按钮 ---
	var ui_node = $UI # 获取UI节点
	if show_debug_buttons:
		ui_node.show()
		var ui_root = ui_node.get_node("MarginContainer/VBoxContainer")
		ui_root.get_node("GlitchButton").pressed.connect(play_glitch)
		ui_root.get_node("DamageButton").pressed.connect(play_damage_effect)
		ui_root.get_node("AberrationButton").pressed.connect(play_color_aberration)
		ui_root.get_node("RollButton").pressed.connect(play_vertical_roll)
	else:
		ui_node.hide() # 如果不显示按钮，则隐藏整个UI节点

# --- 公共API ---

## 播放一次快速的屏幕闪烁和噪点效果。
## 非常适合用于轻微的冲击或UI反馈。
## @param duration: 效果的总持续时间（秒）
## @param intensity: 静态雪花点的强度 (0.0 - 1.0)
func play_glitch(duration: float = 0.2, intensity: float = 0.5):
	if not _shader_material: return
	
	_ensure_tween()
		# 在效果开始时启用滚动
	_shader_material.set_shader_parameter("roll", true)
	
	# 当整个Tween动画播放完毕后，禁用滚动
	_active_tween.finished.connect(func(): _shader_material.set_shader_parameter("roll", false))
	
	# 效果：瞬间增强静态噪点，然后平滑恢复
	_active_tween.tween_property(_shader_material, "shader_parameter/static_noise_intensity", intensity, duration * 0.1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_shader_material, "shader_parameter/static_noise_intensity", _default_static_noise_intensity, duration * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 播放一次带有扭曲和噪点的损坏效果。
## 适合用于表现桥梁受损或被摧毁。
## @param duration: 效果的总持续时间（秒）
## @param distortion: 扭曲强度 (建议 0.1 - 0.2)
## @param noise: 动态条纹噪点强度 (建议 0.5 - 1.0)
func play_damage_effect(duration: float = 0.5, distortion: float = 0.15, noise: float = 0.7):
	if not _shader_material: return
	_ensure_tween()
	
	# 在效果开始时启用滚动
	_shader_material.set_shader_parameter("roll", true)
	
	# 当整个Tween动画播放完毕后，禁用滚动
	_active_tween.finished.connect(func(): _shader_material.set_shader_parameter("roll", false))
	
	# 效果：扭曲和动态噪点同时增强，然后恢复
	_active_tween.tween_property(_shader_material, "shader_parameter/distort_intensity", distortion, duration * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_shader_material, "shader_parameter/distort_intensity", _default_distort_intensity, duration * 0.8).set_delay(duration * 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	_active_tween.tween_property(_shader_material, "shader_parameter/noise_opacity", noise, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(_shader_material, "shader_parameter/noise_opacity", _default_noise_opacity, duration * 0.7).set_delay(duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 播放一次短暂的色彩分离（色差）效果。
## @param duration: 效果总时长
## @param amount: 色彩分离的偏移量 (建议 -0.5 到 0.5)
func play_color_aberration(duration: float = 0.3, amount: float = 0.2):
	if not _shader_material: return

	_ensure_tween()

	# 效果：aberration值从默认 -> amount -> 默认
	_active_tween.tween_property(_shader_material, "shader_parameter/aberration", amount, duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_shader_material, "shader_parameter/aberration", _default_aberration, duration * 0.5).set_delay(duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## 播放一次强烈的垂直滚动（信号失步）效果。
## @param duration: 效果总时长
## @param speed: 滚动速度 (建议 20.0 - 100.0)
## @param distortion: 伴随滚动的扭曲强度 (建议 0.1 - 0.2)
func play_vertical_roll(duration: float = 0.8, speed: float = 40.0, distortion: float = 0.1):
	if not _shader_material: return
	
	_ensure_tween()
	_shader_material.set_shader_parameter("roll", true)
	
	# 当整个Tween动画播放完毕后，禁用滚动
	_active_tween.finished.connect(func(): _shader_material.set_shader_parameter("roll", false))
	
	# 效果：滚动速度和扭曲强度突然增加，然后逐渐恢复正常
	_active_tween.tween_property(_shader_material, "shader_parameter/roll_speed", speed, duration * 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_shader_material, "shader_parameter/roll_speed", _default_roll_speed, duration * 0.9).set_delay(duration * 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	_active_tween.tween_property(_shader_material, "shader_parameter/distort_intensity", distortion, duration * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(_shader_material, "shader_parameter/distort_intensity", _default_distort_intensity, duration * 0.8).set_delay(duration * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- 私有方法 ---

# 确保Tween存在且可用
func _ensure_tween():
	# 如果上一个动画还在播放，先杀掉它，防止冲突
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	
	_active_tween = create_tween()
	# 确保Tween在场景暂停时也能运行（如果需要）
	#_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 确保Tween在完成后自动销毁
	_active_tween.set_parallel(true)
