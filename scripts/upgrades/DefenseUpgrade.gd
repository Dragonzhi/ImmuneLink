extends Upgrade
class_name DefenseUpgrade

## 此升级提供的额外生命值上限
@export var health_increase: float = 50.0
## 此升级提供的每秒生命恢复值
@export var health_regen_per_second: float = 2.0

## 将“防御升级”应用到目标桥梁上
func apply(target: Node) -> void:
	var bridge = target as Bridge
	if not bridge:
		return

	# 1. 将升级的数据写入目标桥梁
	bridge.max_health += health_increase
	# 升级时，也将当前生命值提升同等数额（或直至回满）
	bridge.current_health = min(bridge.current_health + health_increase, bridge.max_health)
	bridge.health_regen += health_regen_per_second
	
	# 2. 更新血条以反映新的生命值上限和当前值
	if bridge.health_bar:
		bridge.health_bar.update_health(bridge.current_health, bridge.max_health, false)
	
	# 3. 调用桥梁自己的方法来更新其视觉效果
	if bridge.has_method("apply_visual_upgrade"):
		bridge.apply_visual_upgrade(self)
	else:
		push_error("Target bridge does not have 'apply_visual_upgrade' method.")

	print("防御升级已应用到桥段 %s" % bridge.grid_pos)
