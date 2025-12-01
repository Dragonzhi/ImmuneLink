extends PathFollow2D
class_name BaseEnemy

const HitEffectScene = preload("res://scenes/effects/HitEffect.tscn")

@export var max_hp: float = 100.0
@export var current_hp: float
@export var move_speed: float = 50.0
@export var damage: float = 10.0

signal path_finished(enemy: BaseEnemy)

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var health_bar_container: Node2D = $HealthBarContainer
@onready var health_bar: ProgressBar = $HealthBarContainer/HealthBar
@onready var sprite: Sprite2D = $Sprite2D

var is_dying: bool = false
var is_spawning: bool = true
var should_delete_at_end: bool = true
var spawner: Node = null # Reference to the spawner that created this enemy
var health_tween: Tween

func _ready() -> void:
	current_hp = max_hp
	rotation_degrees = randf_range(0, 360)
	rotates = false
	if not area_2d.area_entered.is_connected(_on_area_2d_area_entered):
		area_2d.area_entered.connect(_on_area_2d_area_entered)
	_update_health_bar()
	_play_spawn_animation()
	
func _physics_process(delta: float) -> void:
	if is_spawning:
		return
		
	if is_instance_valid(health_bar_container):
		health_bar_container.global_rotation = 0

	if is_dying:
		return

	var path_node = get_parent()
	if not path_node is Path2D:
		return
	
	var path_curve: Curve2D = path_node.curve
	if not path_curve:
		return

	var curve_length: float = path_curve.get_baked_length()
	var new_progress: float = progress + move_speed * delta

	if new_progress >= curve_length:
		emit_signal("path_finished", self)
		if not is_dying:
			if should_delete_at_end:
				progress = curve_length
				queue_free()
			else:
				# Check for new path from spawner
				if spawner and is_instance_valid(spawner) and spawner.has_method("get_active_path"):
					var active_spawner_path = spawner.get_active_path()
					if is_instance_valid(active_spawner_path) and active_spawner_path != path_node:
						# Switch to new path: reparenting resets progress
						path_node.remove_child(self) # Remove from old path
						active_spawner_path.add_child(self) # Add to new path (reparents)
						progress = 0 # Start from the beginning of the new path
						return # Path switched, exit for this frame
				
				# If no path switch, invalid spawner, or path is the same, just loop on current path
				progress = new_progress - curve_length
		else:
			# If it's dying, just stop at the end
			progress = curve_length
	else:
		progress = new_progress

func _on_area_2d_area_entered(area: Area2D) -> void:
	if is_dying: return
	
	if area.owner is Bridge:
		var bridge: Bridge = area.owner
		bridge.take_damage(damage)

func take_damage(amount: float):
	if is_dying: return

	current_hp -= amount
	_update_health_bar()
	
	# --- Create Hit Effect ---
	var hit_effect = HitEffectScene.instantiate()
	get_tree().get_root().get_node("Main/Foreground/Particles").add_child(hit_effect) # Add to main scene
	hit_effect.global_position = global_position
	hit_effect.set_emitting(true)
	# You can customize the color here if needed, e.g., based on damage type
	# hit_effect.set_color(Color.YELLOW) 
	
	if current_hp <= 0:
		start_death_sequence()

func start_death_sequence():
	if is_dying: return

	is_dying = true
	
	if is_instance_valid(health_bar):
		health_bar.hide()
	
	collision_shape.set_deferred("disabled", true)
	
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_QUINT)
	
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 360, 0.5)
	
	tween.finished.connect(queue_free)

func _update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return
	
	var health_percent = (current_hp / max_hp) * 100.0
	
	# Stop the previous tween if it's running
	if health_tween and health_tween.is_running():
		health_tween.kill()

	# Create and configure the new tween
	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_CUBIC)
	health_tween.set_ease(Tween.EASE_OUT)
	health_tween.tween_property(health_bar, "value", health_percent, 0.4)

	if current_hp < max_hp:
		health_bar.show()
	else:
		health_bar.hide()

func _play_spawn_animation():
	scale = Vector2.ZERO
	if is_instance_valid(sprite):
		sprite.modulate.a = 0.0

	var spawn_tween = create_tween()
	spawn_tween.set_parallel()
	spawn_tween.set_ease(Tween.EASE_OUT)
	spawn_tween.set_trans(Tween.TRANS_SINE)

	spawn_tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	if is_instance_valid(sprite):
		spawn_tween.tween_property(sprite, "modulate:a", 1.0, 0.4)

	spawn_tween.finished.connect(func(): is_spawning = false)
