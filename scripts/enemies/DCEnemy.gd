extends BaseEnemy

# --- Bridge Traversal Ability ---
@export_group("Bridge Traversal")
#@export var max_growth_value: float = 50.0  # 被桥梁阻挡多少次后激活能力
#@export var growth_per_block: float = 1.0  # 每次被阻挡时增加的成长值
@export var growth_rate_while_attacking: float = 20.0 # 每秒攻击时获得的成长值
@export var max_growth_value: float = 100.0 # 激活能力所需的总成长值
@export var bridge_traverse_duration: float = 3.0 # 穿行能力持续时间 (秒)
@export var ability_cooldown: float = 8.0 # 能力使用后的冷却时间 (秒)
@export var bridge_collision_layer: int = 3 # 桥所在的物理层级，需要根据项目设置调整

var _growth_value: float = 0.0
var _is_traversing_bridges: bool = false
var _can_use_ability: bool = true

@onready var _ability_timer: Timer = $AbilityTimer
@onready var _reset_timer: Timer = $ResetTimer
@onready var _indicator: CPUParticles2D = $BridgeAbilityIndicator

func _ready():
	super()
	
	if not _ability_timer.is_connected("timeout", _on_ability_timer_timeout):
		_ability_timer.timeout.connect(_on_ability_timer_timeout)
	if not _reset_timer.is_connected("timeout", _on_reset_timer_timeout):
		_reset_timer.timeout.connect(_on_reset_timer_timeout)
		
	if _indicator:
		_indicator.emitting = false

# --- 核心逻辑 ---

# 覆写攻击逻辑，以便在攻击时累积成长值
func _execute_attack(delta: float):
	super(delta) # 执行父类的攻击逻辑（对桥造成伤害）
	
	# 在攻击状态下，并且能力可用时，累积成长值
	if _can_use_ability:
		_growth_value += growth_rate_while_attacking * delta
		# print("DC-Enemy attacking bridge. Growth: %d/%d" % [_growth_value, max_growth_value]) # DEBUG
		if _growth_value >= max_growth_value:
			_activate_bridge_traversal()

# --- Ability State Machine ---

func _activate_bridge_traversal():
	if not _can_use_ability: return

	_growth_value = 0.0
	_is_traversing_bridges = true
	_can_use_ability = false
	
	# 激活视觉提示
	if _indicator:
		_indicator.emitting = true
	
	# 强制进入移动状态，以便开始穿行
	_enter_move_state()
	
	# 禁用与桥梁层的碰撞
	set_collision_mask_value(bridge_collision_layer, false)
	
	print("DC-Enemy: Bridge traversal ACTIVATED for %s seconds." % bridge_traverse_duration) # DEBUG
	_ability_timer.start(bridge_traverse_duration)

func _deactivate_bridge_traversal():
	_is_traversing_bridges = false
	if _indicator:
		_indicator.emitting = false
	
	# 恢复与桥梁层的碰撞
	set_collision_mask_value(bridge_collision_layer, true)
	
	print("DC-Enemy: Bridge traversal DEACTIVATED. Cooldown started for %s seconds." % ability_cooldown) # DEBUG
	_reset_timer.start(ability_cooldown)

func _on_ability_timer_timeout():
	_deactivate_bridge_traversal()

func _on_reset_timer_timeout():
	_can_use_ability = true
	print("DC-Enemy: Ability ready to charge again.") # DEBUG
