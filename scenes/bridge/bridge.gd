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

@export_group("UI")
@export var health_bar: ProgressBar
@export_group("Upgrades")
@export var available_upgrades: Array[Upgrade] = []

var current_health: float
var grid_manager: GridManager
var grid_pos: Vector2i
var is_destroyed: bool = false
# --- 升级相关状态和数据 ---
var is_attack_upgraded: bool = false
var attack_upgrade_damage: float = 0.0
var attack_rate: float = 1.0
var health_regen: float = 0.0 # 新增：每秒生命恢复值

var tile_animation_name: String
var enemies_in_range: Array = []
var _range_indicator # No type hint to avoid parse error

# --- Public API ---

## 获取当前可用的升级列表
func get_available_upgrades() -> Array[Upgrade]:
	var upgrades_to_return: Array[Upgrade] = []
	# 示例逻辑：如果还未升级过攻击，则允许所有升级
	if not is_attack_upgraded: # 这里的逻辑可以根据您的设计调整
		upgrades_to_return = available_upgrades
	return upgrades_to_return

## 公共接口：尝试将一个升级应用到此桥梁
func attempt_upgrade(upgrade: Upgrade):
	if upgrade:
		upgrade.apply(self)

# 由 Upgrade 资源调用，用来更新视觉表现
func apply_visual_upgrade(upgrade: Upgrade):
	if upgrade.icon:
		up_level_sprite.texture = upgrade.icon
		up_level_sprite.visible = true
		#animated_sprite.visible = false # 隐藏原动画
	else:
		# 如果升级没有图标，则使用旧的视觉表现
		up_level_sprite.texture = null # 清除之前的图标
		up_level_sprite.frame = 0
		up_level_sprite.visible = true


# 由 AttackUpgrade 资源调用，用来激活桥梁自身的攻击模式
func activate_attack_mode():
	hit_area.monitorable = true
	hit_area.monitoring = true
	reload_timer.wait_time = 1.0 / attack_rate
	reload_timer.start()
	print("桥段 %s 攻击模式已激活！" % grid_pos)

# --- Godot Lifecycle & Internal Methods ---

func _ready() -> void:
	current_health = max_health
	grid_manager = get_node("/root/Main/GridManager")
	
	health_bar.update_health(current_health, max_health, false)
	
	repair_timer.wait_time = repair_time
	repair_timer.timeout.connect(repair)
	
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	
	hit_area.area_entered.connect(_on_hit_area_area_entered)
	hit_area.area_exited.connect(_on_hit_area_area_exited)
	
	up_level_sprite.visible = false
	hit_area.monitorable = false
	hit_area.monitoring = false

	_range_indicator = AttackRangeIndicatorScene.new()
	add_child(_range_indicator)
	_range_indicator.hide()

func _physics_process(delta: float) -> void:
	# 处理生命恢复
	if health_regen > 0 and not is_destroyed and current_health < max_health:
		current_health += health_regen * delta
		current_health = min(current_health, max_health)
		health_bar.update_health(current_health)

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
	health_bar.update_health(current_health) # 调用血条场景的更新方法
	if current_health <= 0:
		current_health = 0
		is_destroyed = true
		health_bar.hide() # 桥梁摧毁时隐藏血条
		GameCamera.shake(2, 0.3) # 触发相机震动
		animated_sprite.visible = true # 确保摧毁时，原始动画精灵可见
		animated_sprite.modulate = Color(0.4, 0.4, 0.4)
		animated_sprite.stop()
		reload_timer.stop()
		blocking_shape.disabled = true
		
		# 隐藏所有升级相关的视觉效果
		up_level_sprite.visible = false
		if is_attack_upgraded:
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
	
	# 恢复视觉
	animated_sprite.visible = true
	animated_sprite.modulate = Color.WHITE
	animated_sprite.animation = tile_animation_name
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(tile_animation_name) - 1
	up_level_sprite.visible = false
	
	# 检查此桥梁在被摧毁前是否已升级，如果是，则重新应用升级
	if is_attack_upgraded:
		var attack_upgrade = load("res://scripts/upgrades/attack_upgrade_level_1.tres")
		if attack_upgrade:
			attack_upgrade.apply(self)
			
	health_bar.update_health(current_health, max_health, false)

func select():
	# 只有攻击升级后才有攻击范围指示
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
