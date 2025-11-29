extends PathFollow2D
class_name BaseEnemy

@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var move_speed: float = 50.0
@export var damage: float = 10.0

signal path_finished(enemy: BaseEnemy)

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var is_dying: bool = false

func _ready() -> void:
	current_hp = max_hp
	rotates = false
	# This connection is likely made in the editor, but connecting here is safer
	if not area_2d.area_entered.is_connected(_on_area_2d_area_entered):
		area_2d.area_entered.connect(_on_area_2d_area_entered)
	
func _physics_process(delta: float) -> void:
	if is_dying:
		#print("Physics process skipped, I am dying.")
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
		progress = curve_length
		emit_signal("path_finished", self)
		# This is the likely culprit, let's guard it
		if not is_dying:
			# print("Reached end of path, queue_free.")
			queue_free()
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
	print("Took damage, HP is now: ", current_hp)
	if current_hp <= 0:
		start_death_sequence()

func start_death_sequence():
	if is_dying: return

	is_dying = true
	print("Starting death sequence!")
	
	collision_shape.set_deferred("disabled", true)
	
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_QUINT)
	
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 360, 0.5)
	
	tween.finished.connect(queue_free)
