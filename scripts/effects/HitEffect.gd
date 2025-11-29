extends GPUParticles2D

# This function allows other scripts to set the color of the hit flash.
func set_color(hit_color: Color):
	# The 'color' property of the process material controls the base color of the particles.
	process_material.color = hit_color

func _ready() -> void:
	self.finished.connect(queue_free)
