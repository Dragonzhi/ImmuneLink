extends Node2D
class_name Bridge

const CalmingShotScene = preload("res://scenes/projectiles/CalmingShot.tscn")
const AttackRangeIndicatorScene = preload("res://scripts/ui/AttackRangeIndicator.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var repair_timer: Timer = $RepairTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var up_level_sprite: Sprite2D = $UpLevelSprite2D
@onready var hit_area: Area2D = $HitArea2D
@onready var blocking_shape: CollisionShape2D = $BlockingShape

@export var max_health: float = 100.0
@export var repair_time: float = 3.0
@export var attack_upgrade_damage: float = 5.0
@export var attack_rate: float = 1.0 # Attacks per second

var current_health: float
var grid_manager: GridManager
var grid_pos: Vector2i
var is_destroyed: bool = false
var is_attack_upgraded: bool = false
var tile_animation_name: String
var enemies_in_range: Array = []
var _range_indicator # No type hint to avoid parse error

func _ready() -> void:
	current_health = max_health
	grid_manager = get_node("/root/Main/GridManager")
	
	repair_timer.wait_time = repair_time
	repair_timer.timeout.connect(repair)
	
	reload_timer.wait_time = 1.0 / attack_rate
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	
	hit_area.area_entered.connect(_on_hit_area_area_entered)
	hit_area.area_exited.connect(_on_hit_area_area_exited)
	
	up_level_sprite.visible = false
	hit_area.monitorable = false
	hit_area.monitoring = false

	# Create and setup the range indicator
	_range_indicator = AttackRangeIndicatorScene.new()
	add_child(_range_indicator)
	_range_indicator.hide()

func setup_segment(grid_pos: Vector2i):
	self.grid_pos = grid_pos
	if not grid_manager: grid_manager = get_node("/root/Main/GridManager")
	if grid_manager: grid_manager.set_grid_occupied(grid_pos, self)

func setup_bridge_tile(neighbors: Dictionary):
	# ... (auto-tiling logic remains the same)
	var has_north = neighbors.get("north", false)
	var has_south = neighbors.get("south", false)
	var has_east = neighbors.get("east", false)
	var has_west = neighbors.get("west", false)
	var connection_count = [has_north, has_south, has_east, has_west].count(true)
	
	match connection_count:
		4: tile_animation_name = "四向"
		3:
			tile_animation_name = "三向"
			if not has_west: animated_sprite.rotation_degrees = 0
			elif not has_north: animated_sprite.rotation_degrees = 90
			elif not has_east: animated_sprite.rotation_degrees = 180
			elif not has_south: animated_sprite.rotation_degrees = 270
		2:
			if (has_north and has_south):
				tile_animation_name = "二向"
				animated_sprite.rotation_degrees = 0
			elif (has_east and has_west):
				tile_animation_name = "二向"
				animated_sprite.rotation_degrees = 90
			else:
				tile_animation_name = "拐角"
				if has_north and has_east: animated_sprite.rotation_degrees = 0
				elif has_south and has_east: animated_sprite.rotation_degrees = 90
				elif has_south and has_west: animated_sprite.rotation_degrees = 180
				elif has_north and has_west: animated_sprite.rotation_degrees = 270
		1:
			tile_animation_name = "单向"
			if has_south: animated_sprite.rotation_degrees = 0
			elif has_west: animated_sprite.rotation_degrees = 90
			elif has_north: animated_sprite.rotation_degrees = 180
			elif has_east: animated_sprite.rotation_degrees = 270
		_: tile_animation_name = "单向"
	
	animated_sprite.animation = tile_animation_name


func take_damage(amount: float):
	if is_destroyed: return
	current_health -= amount
	if current_health <= 0:
		current_health = 0
		is_destroyed = true
		animated_sprite.modulate = Color(0.4, 0.4, 0.4)
		animated_sprite.stop()
		reload_timer.stop()
		blocking_shape.disabled = true
		if is_attack_upgraded:
			up_level_sprite.visible = false
			hit_area.monitorable = false
			hit_area.monitoring = false
		print("Bridge at %s destroyed. Reporting to GridManager." % grid_pos)
		grid_manager.set_bridge_status(grid_pos, true)
		print("桥段 %s 已被摧毁！" % grid_pos)

func repair():
	is_destroyed = false
	current_health = max_health
	blocking_shape.disabled = false
	grid_manager.set_bridge_status(grid_pos, false)
	animated_sprite.modulate = Color.WHITE
	animated_sprite.animation = tile_animation_name
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(tile_animation_name) - 1
	if is_attack_upgraded:
		apply_attack_upgrade()

func apply_attack_upgrade():
	if is_attack_upgraded: return
	is_attack_upgraded = true
	up_level_sprite.visible = true
	up_level_sprite.frame = 5
	hit_area.monitorable = true
	hit_area.monitoring = true
	reload_timer.start()
	print("桥段 %s 应用了攻击升级！" % grid_pos)

func select():
	if not is_attack_upgraded: return
	
	var collision_shape = hit_area.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		var radius = collision_shape.shape.radius
		_range_indicator.set_attributes(radius, Color(0.2, 0.5, 1.0, 0.2)) # Example color
		_range_indicator.show()

func deselect():
	_range_indicator.hide()

func _on_reload_timer_timeout():
	if enemies_in_range.is_empty():
		return

	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	if enemies_in_range.is_empty():
		return

	var target = enemies_in_range[0]
	var shot = CalmingShotScene.instantiate()
	
	get_tree().get_root().get_node("Main/Foreground/Particles").add_child(shot)
	shot.global_position = global_position
	shot.launch(target, attack_upgrade_damage)

func _on_hit_area_area_entered(area: Area2D):
	if area.get_parent() is BaseEnemy:
		enemies_in_range.append(area.get_parent())

func _on_hit_area_area_exited(area: Area2D):
	if area.get_parent() is BaseEnemy:
		var enemy = area.get_parent()
		if enemies_in_range.has(enemy):
			enemies_in_range.erase(enemy)

func _on_hurt_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_destroyed and repair_timer.is_stopped():
			animated_sprite.modulate = Color(0.2, 0.5, 1.0)
			animated_sprite.animation = tile_animation_name
			animated_sprite.play()
			repair_timer.start()
		elif not is_destroyed:
			GameManager.select_turret(self)

		get_viewport().set_input_as_handled()

func _on_hurt_area_2d_mouse_entered() -> void:
	if not is_destroyed and repair_timer.is_stopped():
		animated_sprite.modulate = Color(0.8, 0.8, 0.8)


func _on_hurt_area_2d_mouse_exited() -> void:
	if not is_destroyed and repair_timer.is_stopped():
		animated_sprite.modulate = Color.WHITE
