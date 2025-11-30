extends Node2D
class_name AttackRangeIndicator

# This script represents a Node2D that draws a circle to indicate a range.

var radius: float = 100.0
var color: Color = Color(1, 1, 1, 0.2) # Default: semi-transparent white

func _draw() -> void:
	# This function is called automatically by the engine to draw the node.
	# We draw a filled circle at the node's local origin (Vector2.ZERO).
	draw_circle(Vector2.ZERO, radius, color)

func set_attributes(new_radius: float, new_color: Color = Color(1, 1, 1, 0.2)):
	"""
	Sets the radius and color of the circle and queues it for redrawing.
	"""
	self.z_index = 100 # Draw on top of other elements
	radius = new_radius
	color = new_color
	# This is crucial. It tells the engine that this node's drawing is
	# out of date and needs to call _draw() again on the next frame.
	queue_redraw()
