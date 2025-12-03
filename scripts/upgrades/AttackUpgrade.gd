extends Upgrade
class_name AttackUpgrade

## 此升级提供的伤害值
@export var damage: float = 5.0
## 此升级提供的攻击速率（每秒攻击次数）
@export var attack_rate: float = 1.0

## 将“攻击升级”应用到目标桥梁上
func apply(target: Node) -> void:
	# 检查目标是否是一个有效的Bridge，以及是否已经升级过
	var bridge = target as Bridge
	if not bridge or bridge.is_attack_upgraded:
		return

	# 1. 将升级的数据写入目标桥梁
	bridge.is_attack_upgraded = true
	bridge.attack_upgrade_damage = damage
	bridge.attack_rate = attack_rate
	
	# 2. 调用桥梁自己的方法来更新其内部状态和视觉效果
	#    这比从这里直接操作桥的子节点要更清晰、更解耦
	if bridge.has_method("activate_attack_mode"):
		bridge.activate_attack_mode()
	else:
		push_error("Target bridge does not have 'activate_attack_mode' method.")

	print("攻击升级已应用到桥段 %s" % bridge.grid_pos)
