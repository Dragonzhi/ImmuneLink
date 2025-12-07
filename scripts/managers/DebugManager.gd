# DebugManager.gd
extends Node

# 一个字典，用于存储每个调试类别的开关状态
# 格式: {"CategoryName": true, "AnotherCategory": false}
var _debug_switches: Dictionary = {}

# --- Public API ---

## 注册一个调试类别，并设置其默认状态
func register_category(category_name: String, enabled_by_default: bool = false):
	if not _debug_switches.has(category_name):
		_debug_switches[category_name] = enabled_by_default
		# 为了调试DebugManager本身，这里用全局print
		print("Debug category '%s' registered with state: %s" % [category_name, enabled_by_default])

## 启用指定类别的调试打印
func enable_debug(category_name: String):
	if _debug_switches.has(category_name):
		_debug_switches[category_name] = true
	else:
		# 类别需要先注册
		printerr("DebugManager: Attempted to enable unregistered category '%s'." % category_name)

## 禁用指定类别的调试打印
func disable_debug(category_name: String):
	if _debug_switches.has(category_name):
		_debug_switches[category_name] = false
	else:
		printerr("DebugManager: Attempted to disable unregistered category '%s'." % category_name)

## 检查某个调试类别是否已启用
func is_category_enabled(category_name: String) -> bool:
	return _debug_switches.get(category_name, false)

## 返回所有已注册的调试类别名称
func get_all_categories() -> Array[String]:
	var category_names: Array[String] = []
	for key in _debug_switches.keys():
		if typeof(key) == TYPE_STRING: # 确保键是字符串类型
			category_names.append(key)
		else:
			printerr("DebugManager: Non-string key found in _debug_switches: %s" % str(key))
	return category_names

## 切换指定类别的调试打印状态
func toggle_category(category_name: String):
	if _debug_switches.has(category_name):
		_debug_switches[category_name] = not _debug_switches[category_name]
	else:
		printerr("DebugManager: Attempted to toggle unregistered category '%s'." % category_name)

## 分类打印函数
func dprint(category_name: String, message: String):
	if is_category_enabled(category_name):
		# 添加类别前缀，方便阅读
		print("[%s] %s" % [category_name.to_upper(), message])
