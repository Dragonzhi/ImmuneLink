extends Upgrade
class_name ConnectionRateUpgrade

## 连接速率的乘数
## 例如: 1.25 表示将速率提升 25% (原始速率 * 1.25)
@export var rate_multiplier: float = 1.25

## 将“连接速率加速”升级应用到目标桥梁上
func apply(target: Node) -> void:
	var bridge = target as Bridge
	if not bridge:
		push_error("ConnectionRateUpgrade can only be applied to a Bridge node.")
		return

	# 通知 ConnectionManager 来应用这个加速效果到桥梁所在的连接上
	if ConnectionManager and ConnectionManager.has_method("apply_boost_to_connection_of_bridge"):
		ConnectionManager.apply_boost_to_connection_of_bridge(bridge, rate_multiplier)
	else:
		push_error("ConnectionManager is not available or does not have 'apply_boost_to_connection_of_bridge' method.")

	# 应用视觉效果
	if bridge.has_method("apply_visual_upgrade"):
		bridge.apply_visual_upgrade(self)
	
	print("连接速率加速升级 (泵) 已应用到桥段 %s，乘数: %s" % [bridge.grid_pos, rate_multiplier])
