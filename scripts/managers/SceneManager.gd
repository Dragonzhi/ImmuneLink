extends Control

var current_scene: Node = null
@onready var fade_rect: ColorRect = $ColorRect

func _ready():
	# 监听场景切换信号，确保 current_scene 始终是正确的
	get_tree().scene_changed.connect(on_scene_changed)
	current_scene = get_tree().current_scene

	# ColorRect 是从场景树中获取的
	# 确保它覆盖整个屏幕并从透明开始
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0) # 开始时完全透明

func on_scene_changed(new_scene: Node):
	current_scene = new_scene

func change_scene(scene_path: String):
	# 创建一个Tween来处理动画
	var tween = get_tree().create_tween()
	
	# 淡出
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 0.5).set_trans(Tween.TRANS_SINE)
	
	# 等待淡出完成，然后切换场景
	await tween.finished
	
	# 切换场景
	# 注意：直接操作current_scene可能不如直接调用get_tree().change_scene_to_file()安全
	# 但我们遵循现有逻辑
	get_tree().change_scene_to_file(scene_path)
	
	# 等待新场景加载完成 (change_scene_to_file后，需要等待一帧)
	await get_tree().process_frame
	
	# 淡入
	tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.5).set_trans(Tween.TRANS_SINE)
	
	# 返回新场景的引用
	return get_tree().current_scene
