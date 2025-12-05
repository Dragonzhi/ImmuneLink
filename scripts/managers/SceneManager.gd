<<<<<<< HEAD
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
=======
extends Control
@onready var transition_rect: ColorRect = $ColorRect

var is_transitioning: bool = false
var active_tween: Tween
var _end_screen_data: Dictionary = {} # 用于在场景间传递数据

func _ready():
	# Connect to the scene_changed signal to robustly reset the transitioning flag.
	get_tree().scene_changed.connect(_on_scene_changed)
	
	if is_instance_valid(transition_rect):
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 确保初始状态是完全透明且隐藏的
		transition_rect.modulate = Color(transition_rect.modulate.r, transition_rect.modulate.g, transition_rect.modulate.b, 0.0)
		transition_rect.hide()
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	# 初始化 Tween，但不立即使用
	# active_tween = get_tree().create_tween().bind_node(self)
	# active_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

func _on_scene_changed():
	is_transitioning = false

# --- Public API ---

func change_to_end_screen(is_win: bool, stats: Dictionary):
	_end_screen_data = { "is_win": is_win, "stats": stats }
	change_scene("res://scenes/ui/screens/EndScreen.tscn")

func get_end_screen_data() -> Dictionary:
	return _end_screen_data

func change_scene(scene_path: String):
	if is_transitioning:
		return
	is_transitioning = true
	_perform_scene_change(scene_path)

func _perform_scene_change(scene_path: String):
	if not is_instance_valid(transition_rect):
		push_error("transition_rect is not valid!")
		get_tree().change_scene_to_file(scene_path) # 直接切换，不过渡
		return
		
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	# 1. 设置 transition_rect 初始状态 (完全透明, 可见)
	transition_rect.show()
	transition_rect.modulate = Color(transition_rect.modulate.r, transition_rect.modulate.g, transition_rect.modulate.b, 0.0)
	
	active_tween = get_tree().create_tween().bind_node(self)
	active_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	# 2. 渐入 (Fade Out Current Scene)
	# 动画：让 transition_rect 的 alpha 值在 0.5 秒内从 0.0 变为 1.0 (完全不透明)
	active_tween.tween_property(transition_rect, "modulate", 
								Color(transition_rect.modulate.r, transition_rect.modulate.g, transition_rect.modulate.b, 1.0), 
								0.5)

	# 3. 动画完成后，调用 _on_fade_out_finished 切换场景
	active_tween.finished.connect(Callable(self, "_on_fade_out_finished").bind(scene_path))

# 当淡出动画完成时，此函数被调用
func _on_fade_out_finished(scene_path: String):
	# 1. 切换到新的场景 (此时屏幕被 transition_rect 完全覆盖)
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to: ", scene_path)
		is_transitioning = false
		return
		
	# 2. 重新创建 Tween 来处理渐出动画
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = get_tree().create_tween().bind_node(self)
	active_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	# 3. 渐出 (Fade In New Scene)
	# 动画：让 transition_rect 的 alpha 值在 0.5 秒内从 1.0 变为 0.0 (完全透明)
	active_tween.tween_property(transition_rect, "modulate", 
								Color(transition_rect.modulate.r, transition_rect.modulate.g, transition_rect.modulate.b, 0.0), 
								0.5)

	# 4. 动画完成后，隐藏 transition_rect
	active_tween.finished.connect(Callable(self, "_on_fade_in_finished"))

func _on_fade_in_finished():
	if is_instance_valid(transition_rect):
		transition_rect.hide()
	# is_transitioning 会在 _on_scene_changed 中被重置
>>>>>>> main
