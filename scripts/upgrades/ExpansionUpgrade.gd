extends Upgrade
class_name ExpansionUpgrade

## 将“扩展升级”应用到目标桥梁上
func apply(target: Node) -> void:
	var bridge = target as Bridge
	if not bridge:
		push_error("ExpansionUpgrade can only be applied to a Bridge node.")
		return

	# 检查桥梁是否有可用的连接点
	if bridge.has_method("get_connection_count"):
		# 假设一个桥梁最多4个连接点
		if bridge.get_connection_count() >= 4:
			print("升级失败: 此桥梁段已没有可用的扩展接口。")
			# 在实际游戏中，可以在UI层面就阻止这次升级
			# 临时返还资源
			GameManager.add_resource_value(cost)
			return

	# 调用桥梁自己的方法来切换状态，并将自身传递过去
	if bridge.has_method("enter_expansion_waiting_state"):
		bridge.enter_expansion_waiting_state(self)
	else:
		push_error("Target bridge does not have 'enter_expansion_waiting_state' method.")

	print("扩展升级已应用到桥段 %s，正在等待连接..." % bridge.grid_pos)
