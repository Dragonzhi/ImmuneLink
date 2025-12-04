extends Node

var transition_rect: ColorRect
var shader_material: ShaderMaterial
var is_transitioning: bool = false
var active_tween: Tween
var _end_screen_data: Dictionary = {} # 用于在场景间传递数据

const DISSOLVE_SHADER = preload("res://assets/shaders/dissolve.gdshader")

func _ready():
	# Connect to the scene_changed signal to robustly reset the transitioning flag.
	get_tree().scene_changed.connect(_on_scene_changed)
	
	if not is_instance_valid(transition_rect):
		transition_rect = ColorRect.new()
		transition_rect.name = "SceneTransitionRect"
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		shader_material = ShaderMaterial.new()
		shader_material.shader = DISSOLVE_SHADER
		transition_rect.material = shader_material
		
		get_tree().root.add_child(transition_rect)
		transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		transition_rect.z_index = 1000
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	shader_material.set_shader_parameter("progress", 1.0)
	
	active_tween = get_tree().create_tween().bind_node(self)
	active_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	active_tween.tween_property(shader_material, "shader_parameter/progress", 0.0, 0.7).set_trans(Tween.TRANS_SINE)

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
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	shader_material.set_shader_parameter("progress", 0.0)
		
	active_tween = get_tree().create_tween().bind_node(self)
	active_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	active_tween.tween_property(shader_material, "shader_parameter/progress", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	
	active_tween.finished.connect(Callable(self, "_on_fade_out_finished").bind(scene_path))

# 当淡出动画完成时，此函数被调用
func _on_fade_out_finished(scene_path: String):
	get_tree().change_scene_to_file(scene_path)
