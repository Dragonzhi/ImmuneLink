# DebugManager.gd
extends Node

# 设置为 true 以启用所有 dprint 语句, 设置为 false 以禁用它们。
static var is_debug_enabled: bool = true

# 全局可用的打印函数
func dprint(message: String):
	if is_debug_enabled:
		print(message)
