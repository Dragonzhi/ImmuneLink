extends Area2D
class_name CalmingShot

var speed: float = 200.0
var damage: float = 10.0
var target: Node2D = null
var is_dying: bool = false

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var deletion_timer: Timer = $DeletionTimer
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func launch(shot_target: Node2D, shot_damage: float):
	target = shot_target
	damage = shot_damage

func _ready() -> void:
	lifetime_timer.timeout.connect(start_fade_out)
	deletion_timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if is_dying:
		return # Fading out, no more logic needed

	if not is_instance_valid(target):
		start_fade_out() # Target is gone, start fading out
		return
	
	var direction = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D):
	if is_dying: return # Already hit something
	
	if area.get_parent() is BaseEnemy:
		var enemy: BaseEnemy = area.get_parent()
		# Only damage the intended target
		if enemy == target:
			enemy.take_damage(damage)
			start_fade_out()

func start_fade_out():
	if is_dying: return # Already fading out

	is_dying = true
	speed = 0 # Stop movement
	collision_shape.set_deferred("disabled", true) # Disable further collisions safely
	particles.emitting = false # Stop emitting new particles
	deletion_timer.start() # Start final countdown to deletion
