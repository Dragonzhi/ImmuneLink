extends Node

## 简单的场景管理器，提供带淡入淡出效果的场景切换功能。

var transition_rect: ColorRect
var tween: Tween

func _ready():
	# -- 程序化创建UI --
	# 创建一个CanvasLayer以确保转场UI永远在最顶层
	var canvas = CanvasLayer.new()
	canvas.layer = 128 # 设置一个很高的层级，确保在所有UI之上
	add_child(canvas)

	# 创建用于转场的ColorRect
	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0) # 初始为全黑但完全透明
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # 不阻挡鼠标
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 覆盖全屏
	canvas.add_child(transition_rect)

	# -- 连接信号 --
	# 当场景切换完成后，触发淡入
	get_tree().scene_changed.connect(_on_scene_changed)


# --- 公共API ---

## 调用此函数来切换到新场景
func change_scene_to_file(scene_path: String):
	# 防止在转场时重复触发
	if tween and tween.is_running():
		return

	# 1. 淡出
	tween = create_tween()
	# 动画：在0.4秒内将黑色矩形的alpha值变为1（完全不透明）
	transition_rect.visible = true # 在动画开始前设为可见
	tween.tween_property(transition_rect, "color:a", 1.0, 0.4)
	
	# 2. 等待淡出动画完成
	await tween.finished

	# 3. 切换场景
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		# 如果路径错误，则直接淡入，避免卡在黑屏
		_on_scene_changed()


# --- 信号处理 ---

# 当新场景加载完毕后，此函数会被自动调用
func _on_scene_changed():
	# 4. 淡入
	tween = create_tween()
	# 动画：在0.4秒内将黑色矩形的alpha值变为0（完全透明）
	tween.tween_property(transition_rect, "color:a", 0.0, 0.4)
	
	# 5. 等待淡入动画完成
	await tween.finished
	
	# 6. 彻底隐藏转场矩形，防止任何输入问题
	transition_rect.visible = false
