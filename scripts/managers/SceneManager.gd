extends Node

var current_scene: Node = null
var fade_rect: ColorRect = null

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

	# 创建一个用于淡入淡出的ColorRect
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) # 开始时完全透明
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 将其直接添加到根视口，确保它在最顶层
	get_tree().root.add_child(fade_rect)
	# 确保它覆盖整个屏幕
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 确保它在最顶层
	fade_rect.z_index = 1000

func change_scene(scene_path: String):
	# 创建一个Tween来处理动画
	var tween = get_tree().create_tween()
	
	# 淡出
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 0.5).set_trans(Tween.TRANS_SINE)
	
	# 等待淡出完成，然后切换场景
	await tween.finished
	
	# 切换场景
	if current_scene:
		current_scene.queue_free()
	
	var next_scene_packed = load(scene_path)
	if next_scene_packed:
		current_scene = next_scene_packed.instantiate()
		get_tree().root.add_child(current_scene)
	
	# 淡入
	tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.5).set_trans(Tween.TRANS_SINE)
