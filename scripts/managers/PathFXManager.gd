extends Node2D

var active_animations: Dictionary = {}
const SEGMENT_LENGTH = 30 # How many points long the "comet" is

# This function will be called from the EnemySpawnPoint
func play_path_animation(path_node: Path2D):
	# Avoid spamming the animation for the same path
	if path_node in active_animations:
		if active_animations[path_node].is_running():
			return

	if not is_instance_valid(path_node) or not path_node.curve:
		return

	var line = Line2D.new()
	# CRITICAL FIX: Set the transform of the line to match the path's transform
	# This ensures the line is drawn in the correct position and rotation.
	line.global_transform = path_node.global_transform
	
	line.width = 2.0
	line.default_color = Color(0.8, 1.0, 1.0, 0.8) # A slightly transparent, bright cyan
	line.antialiased = true
	
	# Create a simple "comet" effect with a gradient
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.1, 0.1, 1)) # Head of the comet (white)
	gradient.set_color(1, Color(1, 1, 1, 0)) # Tail of the comet (transparent)
	line.gradient = gradient
	
	# Add to the main scene tree so it's visible
	# Adding to 'self' is fine now since 'self' is a Node2D in the scene tree
	add_child(line)

	var curve = path_node.curve
	var full_points = curve.get_baked_points()
	if full_points.size() < 2:
		return

	var tween = create_tween()
	active_animations[path_node] = tween

	var total_points = full_points.size()
	var total_animation_length = float(total_points + SEGMENT_LENGTH)
	var duration = 0.8 # Fixed duration for consistency

	# This is a custom callable that will be executed by the tween on each frame
	var update_line_callable = func(virtual_pos: float):
		_update_line_points(line, full_points, virtual_pos)

	tween.tween_method(update_line_callable, 0.0, total_animation_length, duration)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)

	# When the animation finishes, clean up
	tween.finished.connect(func():
		if is_instance_valid(line):
			line.queue_free()
		if active_animations.has(path_node):
			active_animations.erase(path_node)
	)

func _update_line_points(line: Line2D, full_points: PackedVector2Array, virtual_head_position: float):
	if not is_instance_valid(line):
		return
	
	var total_points = full_points.size()
	
	var head_index = int(virtual_head_position)
	var tail_index = int(virtual_head_position - SEGMENT_LENGTH)
	
	# Clamp indices to the valid range of the points array
	head_index = min(head_index, total_points)
	tail_index = max(0, tail_index)
	
	if head_index > tail_index:
		line.points = full_points.slice(tail_index, head_index)
	else:
		line.points = []
