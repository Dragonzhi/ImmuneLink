extends PathFollow2D
class_name BaseEnemy

const HitEffectScene = preload("res://scenes/effects/HitEffect.tscn")

@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var move_speed: float = 50.0
@export var damage: float = 10.0

signal path_finished(enemy: BaseEnemy)

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var is_dying: bool = false
var should_delete_at_end: bool = true

func _ready() -> void:
	current_hp = max_hp
	rotates = false
	if not area_2d.area_entered.is_connected(_on_area_2d_area_entered):
		area_2d.area_entered.connect(_on_area_2d_area_entered)
	
func _physics_process(delta: float) -> void:
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
				# Loop back to the beginning, carrying over the remainder
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
	
	collision_shape.set_deferred("disabled", true)
	
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_QUINT)
	
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 360, 0.5)
	
	tween.finished.connect(queue_free)
