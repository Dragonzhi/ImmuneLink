extends Node

var transition_rect: ColorRect
var is_transitioning: bool = false

func _ready():
	# -- 程序化创建UI --
	var canvas = CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)

	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(transition_rect)


# --- 公共API ---

## 调用此函数来切换到新场景
func change_scene_to_file(scene_path: String):
	if is_transitioning:
		return
	is_transitioning = true

	# 1. 淡出
	var tween_out = create_tween()
	transition_rect.visible = true
	tween_out.tween_property(transition_rect, "color:a", 1.0, 0.4)
	await tween_out.finished

	# 2. 切换场景
	var error = get_tree().change_scene_to_file(scene_path)
	
	# 如果路径错误，直接淡入返回，避免卡死
	if error != OK:
		var tween_err = create_tween()
		tween_err.tween_property(transition_rect, "color:a", 0.0, 0.4)
		await tween_err.finished
		transition_rect.visible = false
		is_transitioning = false
		return

	# 3. 等待场景切换完成的信号，并获取新场景节点
	var new_scene = await get_tree().scene_changed

	# 4. 通知其他需要新场景信息的管理器
	if GameManager and GameManager.has_method("notify_scene_changed"):
		GameManager.notify_scene_changed(new_scene)
		
	# 5. 淡入
	var tween_in = create_tween()
	tween_in.tween_property(transition_rect, "color:a", 0.0, 0.4)
	await tween_in.finished
	
	# 6. 收尾
	transition_rect.visible = false
	is_transitioning = false
