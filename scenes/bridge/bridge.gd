extends Node2D
class_name Bridge

const CalmingShotScene = preload("res://scenes/projectiles/CalmingShot.tscn")
const AttackRangeIndicatorScene = preload("res://scripts/ui/AttackRangeIndicator.gd")

# --- 预加载升级脚本以进行可靠的类型检查 ---
const AttackUpgradeScript = preload("res://scripts/upgrades/AttackUpgrade.gd")
const DefenseUpgradeScript = preload("res://scripts/upgrades/DefenseUpgrade.gd")
const ConnectionRateUpgradeScript = preload("res://scripts/upgrades/ConnectionRateUpgrade.gd")
const ExpansionUpgradeScript = preload("res://scripts/upgrades/ExpansionUpgrade.gd")
const NKProtocolUpgradeResource = preload("res://scripts/upgrades/resourses/NKProtocolUpgrade.tres")

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
@export var is_secondary: bool = false # 是否为扩展出来的桥梁
@export var secondary_color: Color = Color.WHITE # 次级桥梁的颜色，默认为白色

var bridge_builder_instance:BridgeBuilder = null

# --- 状态机 ---
enum State { NORMAL, DESTROYED, EXPANSION_WAITING }
var current_bridge_state: State = State.NORMAL
var _pending_expansion_upgrade: Upgrade = null # 暂存待处理的扩展升级资源

var current_health: float
var grid_manager: GridManager
var grid_pos: Vector2i
var is_destroyed: bool = false

# --- 升级系统状态 ---
var current_upgrade: Upgrade = null # 当前生效的升级
var upgrade_level: int = 0         # 当前升级的叠加等级
var _base_stats: Dictionary = {}   # 用于存储桥梁的初始属性

# --- 升级相关状态和数据 ---
var is_attack_upgraded: bool = false
var is_nk_upgraded: bool = false # 新增：追踪桥梁是否已是NK升级桥梁
var attack_upgrade_damage: float = 0.0
var attack_rate: float = 1.0
var health_regen: float = 0.0 

var tile_animation_name: String
var neighbors: Dictionary = {} # 存储邻居连接信息
var enemies_in_range: Array = []
var _range_indicator 

# --- Public API ---

## 获取当前已连接的邻居数量
func get_connection_count() -> int:
	var count = 0
	if neighbors.get("north", false): count += 1
	if neighbors.get("south", false): count += 1
	if neighbors.get("east", false): count += 1
	if neighbors.get("west", false): count += 1
	return count

## 进入“等待扩展连接”状态
func enter_expansion_waiting_state(upgrade_res: Upgrade):
	if current_bridge_state != State.NORMAL: return
	current_bridge_state = State.EXPANSION_WAITING
	_pending_expansion_upgrade = upgrade_res
	
	if up_level_sprite.visible:
		up_level_sprite.modulate = Color.AQUA
	else:
		animated_sprite.modulate = Color.AQUA
	
	if _range_indicator.visible:
		deselect()
	GameManager.deselect_all_turrets()
	
	print("Bridge at %s entered EXPANSION_WAITING state." % grid_pos)

## 取消“等待扩展连接”状态，并返还资源
func cancel_expansion():
	if current_bridge_state != State.EXPANSION_WAITING: return
	
	current_bridge_state = State.NORMAL
	
	# 返还资源
	if _pending_expansion_upgrade:
		GameManager.add_resource_value(_pending_expansion_upgrade.cost)
		_pending_expansion_upgrade = null
	
	# 恢复视觉
	if up_level_sprite.visible:
		up_level_sprite.modulate = Color.WHITE
	else:
		animated_sprite.modulate = Color.WHITE
	
	print("Bridge at %s cancelled EXPANSION_WAITING state." % grid_pos)

## 在扩展连接成功后，完成并退出等待状态
func complete_expansion():
	if current_bridge_state != State.EXPANSION_WAITING: return
	
	current_bridge_state = State.NORMAL
	_pending_expansion_upgrade = null
	
	# 恢复视觉
	if up_level_sprite.visible:
		up_level_sprite.modulate = Color.WHITE
	else:
		animated_sprite.modulate = Color.WHITE
	
	print("Bridge at %s completed EXPANSION." % grid_pos)


## 强制刷新此桥梁的连接状态和视觉样式
func update_connections():
	if not grid_manager: grid_manager = GridManager
	
	var new_neighbors = {}
	var north_pos = grid_pos + Vector2i.UP
	var south_pos = grid_pos + Vector2i.DOWN
	var east_pos = grid_pos + Vector2i.RIGHT
	var west_pos = grid_pos + Vector2i.LEFT
	
	if grid_manager.get_grid_object(north_pos): new_neighbors["north"] = true
	if grid_manager.get_grid_object(south_pos): new_neighbors["south"] = true
	if grid_manager.get_grid_object(east_pos): new_neighbors["east"] = true
	if grid_manager.get_grid_object(west_pos): new_neighbors["west"] = true
	
	# 使用新的邻居信息调用瓦片设置函数
	setup_bridge_tile(new_neighbors)


## 获取当前可用的升级列表
func get_available_upgrades() -> Array[Upgrade]:
	var upgrades_to_return: Array[Upgrade] = []
	
	# 只有在常规状态下才可升级
	if current_bridge_state != State.NORMAL:
		return upgrades_to_return
		
	# --- 新增：检查并添加NK协议升级 ---
	if GameManager.get_nk_cell_samples() > 0 and not is_nk_upgraded:
		upgrades_to_return.append(NKProtocolUpgradeResource)
	
	var on_active_line = false
	if ConnectionManager and ConnectionManager.has_method("is_bridge_on_active_line"):
		on_active_line = ConnectionManager.is_bridge_on_active_line(self)

	for upgrade_resource in available_upgrades:
		var script = upgrade_resource.get_script()
		if script == AttackUpgradeScript:
			upgrades_to_return.append(upgrade_resource)
		elif script == DefenseUpgradeScript:
			# 防御升级目前没有特殊条件，始终可升级
			upgrades_to_return.append(upgrade_resource)
		elif script == ConnectionRateUpgradeScript:
			# 扩展桥梁（二级桥梁）不能进行速率升级
			if on_active_line and not is_secondary:
				upgrades_to_return.append(upgrade_resource)
		elif script == ExpansionUpgradeScript:
			# 扩展桥梁不能再扩展，且连接数必须小于4
			if not is_secondary and get_connection_count() < 4:
				upgrades_to_return.append(upgrade_resource)
	
	return upgrades_to_return

## 公共接口：尝试将一个升级应用到此桥梁
func attempt_upgrade(new_upgrade: Upgrade):
	if not new_upgrade: return

	var new_upgrade_script = new_upgrade.get_script()

	# --- 首次升级 ---
	if not current_upgrade:
		current_upgrade = new_upgrade
		upgrade_level = 1
		_apply_upgrade_effects(new_upgrade)
		return

	# --- 后续升级 ---
	var current_upgrade_script = current_upgrade.get_script()

	if new_upgrade_script == current_upgrade_script:
		# 类型相同，进行叠加
		upgrade_level += 1
		_apply_upgrade_effects(new_upgrade) # 应用增量
		_update_stack_visuals() # 更新视觉
		print("Upgrade stacked. Level: %d" % upgrade_level)
	else:
		# 类型不同，先重置再应用新升级
		_reset_to_base_stats()
		current_upgrade = new_upgrade
		upgrade_level = 1
		_apply_upgrade_effects(new_upgrade)
		print("Upgrade reset and changed.")

# --- 升级系统辅助函数 ---

func _reset_to_base_stats():
	"""将桥梁的属性和视觉重置到初始状态。"""
	max_health = _base_stats["max_health"]
	health_regen = _base_stats["health_regen"]
	attack_upgrade_damage = _base_stats["attack_upgrade_damage"]
	attack_rate = _base_stats["attack_rate"]
	animated_sprite.modulate = _base_stats["modulate"]
	up_level_sprite.modulate = Color.WHITE # 重置升级图标的颜色
	is_attack_upgraded = _base_stats["is_attack_upgraded"]
	is_nk_upgraded = _base_stats["is_nk_upgraded"] # 重置NK升级状态

	# 重置状态变量
	current_upgrade = null
	upgrade_level = 0
	
	# 如果有攻击模式，需要禁用
	up_level_sprite.visible = false
	hit_area.monitorable = false
	hit_area.monitoring = false
	reload_timer.stop()
	
	print("Bridge stats have been reset to base.")

func _apply_upgrade_effects(upgrade: Upgrade):
	"""根据Upgrade资源的类型，集中处理属性修改。"""
	var script = upgrade.get_script()

	# 根据脚本类型来判断升级效果
	if script == AttackUpgradeScript:
		is_attack_upgraded = true
		attack_upgrade_damage += upgrade.damage # 使用正确的属性名
		attack_rate += upgrade.attack_rate # 将速率改为加法
		activate_attack_mode() # 激活攻击模式
		apply_visual_upgrade(upgrade)

	elif script == DefenseUpgradeScript:
		max_health += upgrade.health_increase
		health_regen += upgrade.health_regen_per_second
		# 防御升级也可能有视觉变化
		apply_visual_upgrade(upgrade)

	elif script == ConnectionRateUpgradeScript:
		# 通知 ConnectionManager 来应用这个加速效果
		if ConnectionManager:
			ConnectionManager.apply_boost_to_connection_of_bridge(self, upgrade.rate_multiplier)
		apply_visual_upgrade(upgrade)

	elif script == NKProtocolUpgradeResource.get_script(): # 处理NK协议升级
		if GameManager.spend_nk_cell_sample(1):
			is_nk_upgraded = true
			# 激活NK协议后的视觉效果
			_update_nk_visuals() # 新函数：更新NK协议的视觉效果
			apply_visual_upgrade(upgrade)
			print("NK Protocol activated on bridge %s." % grid_pos)
		else:
			printerr("GameManager: 资源不足（NK样本），无法应用NK协议升级。")
			# 可以在此处回滚升级界面或给用户提示


	elif script == ExpansionUpgradeScript:
		# 扩展升级的逻辑比较特殊，它会改变桥梁的状态
		# 这里的调用会触发一个等待用户绘制新桥梁的流程
		enter_expansion_waiting_state(upgrade)
		# 注意：扩展升级本身不应该叠加，get_available_upgrades中已有逻辑阻止
	
	# 更新生命值（例如，增加最大生命值后，当前生命值也应相应增加）
	current_health = min(max_health, current_health + (upgrade.health_increase if "health_increase" in upgrade else 0))
	health_bar.update_health(current_health, max_health)


func _update_stack_visuals():
	"""根据叠加等级微调桥梁颜色。"""
	if not "modulate" in _base_stats: return

	var base_color: Color = _base_stats["modulate"]
	# 目标颜色，选择一个更饱和、更明显的颜色
	const TARGET_COLOR = Color.DODGER_BLUE
	
	# 叠加因子，让每级的变化更明显
	var factor = clamp(float(upgrade_level - 1) * 0.35, 0.0, 1.0)
	
	animated_sprite.modulate = base_color # 恢复基础桥梁颜色
	up_level_sprite.modulate = base_color.lerp(TARGET_COLOR, factor)

func _update_nk_visuals():
	"""更新NK协议激活后的视觉效果。"""
	# 使用一个独特的颜色来表示NK协议激活的桥梁
	animated_sprite.modulate = Color.LIME_GREEN.lerp(Color.WHITE, 0.5) # 淡绿色
	# 可以选择隐藏up_level_sprite或改变其图标，表示这是“最终”升级之一
	# up_level_sprite.visible = false


# 由 Upgrade 资源调用，用来更新视觉表现
func apply_visual_upgrade(upgrade: Upgrade):
	if upgrade.icon:
		up_level_sprite.texture = upgrade.icon
		up_level_sprite.visible = true
	else:
		up_level_sprite.texture = null 
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
	# --- 保存初始属性，用于升级重置 ---
	_base_stats["max_health"] = max_health
	_base_stats["health_regen"] = health_regen
	_base_stats["attack_upgrade_damage"] = 0.0 # 攻击力初始为0
	_base_stats["attack_rate"] = 1.0 # 攻击速率初始为1
	_base_stats["modulate"] = animated_sprite.modulate # 初始颜色
	_base_stats["is_attack_upgraded"] = false
	_base_stats["is_nk_upgraded"] = false # 初始NK升级状态
	
	current_health = max_health
	grid_manager = GridManager
	
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
	
	bridge_builder_instance = get_tree().get_root().find_child("BridgeBuilder", true, false)

func _physics_process(delta: float) -> void:
	# 处理生命恢复
	if health_regen > 0 and current_bridge_state != State.DESTROYED and current_health < max_health:
		current_health += health_regen * delta
		current_health = min(current_health, max_health)
		health_bar.update_health(current_health)

func setup_segment(grid_pos: Vector2i):
	self.grid_pos = grid_pos
	if not grid_manager: grid_manager = GridManager
	if grid_manager: grid_manager.set_grid_occupied(grid_pos, self)

func setup_bridge_tile(neighbors: Dictionary):
	self.neighbors = neighbors # 保存邻居信息
	
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
	animated_sprite.animation = tile_animation_name
	animated_sprite.play()
	animated_sprite.frame = 0


func set_sprite_modulate(color: Color):
	animated_sprite.modulate = color


func take_damage(amount: float):
	if current_bridge_state == State.DESTROYED: return
	current_health -= amount
	health_bar.update_health(current_health) 
	if current_health <= 0:
		current_health = 0
		is_destroyed = true
		current_bridge_state = State.DESTROYED
		
		health_bar.hide() 
		GameCamera.shake(1, 0.3) 
		animated_sprite.visible = true 
		animated_sprite.modulate = Color(0.4, 0.4, 0.4)
		animated_sprite.stop()
		reload_timer.stop()
		blocking_shape.disabled = true
		
		up_level_sprite.visible = false
		if is_attack_upgraded:
			hit_area.monitorable = false
			hit_area.monitoring = false

		print("Bridge at %s destroyed. Reporting to GridManager." % grid_pos)
		grid_manager.set_bridge_status(grid_pos, true)
		print("桥段 %s 已被摧毁！" % grid_pos)

func repair():
	is_destroyed = false
	current_bridge_state = State.NORMAL
	
	current_health = max_health
	blocking_shape.disabled = false
	grid_manager.set_bridge_status(grid_pos, false)
	
	animated_sprite.visible = true
	animated_sprite.modulate = Color.WHITE
	animated_sprite.animation = tile_animation_name
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(tile_animation_name) - 1
	up_level_sprite.visible = false
	
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
	# 根据状态处理输入
	match current_bridge_state:
		State.NORMAL:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				GameManager.select_turret(self)
				get_viewport().set_input_as_handled()
		State.DESTROYED:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				if repair_timer.is_stopped(): # 只有在修复计时器停止时才能尝试修复
					animated_sprite.modulate = Color(0.2, 0.5, 1.0)
					animated_sprite.animation = tile_animation_name
					animated_sprite.play()
					repair_timer.start()
					get_viewport().set_input_as_handled()
		State.EXPANSION_WAITING:
			if event is InputEventMouseButton and event.is_pressed():
				if event.button_index == MOUSE_BUTTON_LEFT:
					# 通知 BridgeBuilder 从这个桥梁开始画线
					bridge_builder_instance.start_building_from_bridge(self)
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					cancel_expansion()
					get_viewport().set_input_as_handled()


func _on_hurt_area_2d_mouse_entered() -> void:
	# 只有在常规状态下才显示鼠标悬停效果
	if current_bridge_state == State.NORMAL:
		if is_secondary:
			animated_sprite.modulate = secondary_color.lightened(0.2)
		else:
			animated_sprite.modulate = Color.WHITE.darkened(0.1)


func _on_hurt_area_2d_mouse_exited() -> void:
	# 只有在常规状态下才恢复鼠标悬停效果
	if current_bridge_state == State.NORMAL:
		if is_secondary:
			animated_sprite.modulate = secondary_color
		else:
			animated_sprite.modulate = Color.WHITE
