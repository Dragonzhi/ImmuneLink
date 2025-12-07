extends Control

# 信号，当按钮被点击时发出。传递的是具体的 Upgrade 资源，而不是索引。
signal upgrade_selected(upgrade: Upgrade)

@export var button_scene: PackedScene # 如果有自定义按钮场景，可以在这里设置
@export var button_radius: float = 60.0
@export var button_default_size: Vector2 = Vector2(100, 60) # 调整默认尺寸以适应24x24图标和文本
@export var button_font_size: int = 14 # 新增：按钮文本的字体大小

var selected_bridge: Bridge = null # 对当前选中的桥梁的引用

# 动态创建并布置按钮，基于传入的升级列表
func populate_menu(upgrades: Array[Upgrade], target_bridge: Bridge):
	self.selected_bridge = target_bridge
	var current_resources = GameManager.get_resource_value() # 获取当前资源
	
	# 清理旧按钮
	for child in get_children():
		child.queue_free()
		
	if upgrades.is_empty():
		return

	var angle_step = (2 * PI) / upgrades.size()

	for i in range(upgrades.size()):
		var upgrade_res: Upgrade = upgrades[i]
		var angle = angle_step * i
		
		var button: Button
		if button_scene:
			button = button_scene.instantiate()
		else:
			button = Button.new()
			# 从Upgrade资源获取信息来设置按钮
			button.icon = upgrade_res.icon
			button.text = "%s\n(%s G)" % [upgrade_res.upgrade_name, upgrade_res.cost]
			button.add_theme_font_size_override("font_size", button_font_size) # 应用字体大小
		
		# --- 新增：检查资源是否足够 ---
		if current_resources < upgrade_res.cost:
			button.disabled = true
		# --------------------------
		
		# 强制应用尺寸，无论按钮是如何创建的
		button.custom_minimum_size = button_default_size
		# 移除测试：button.clip_text = true 
		
		add_child(button)
		
		var x = button_radius * cos(angle)
		var y = button_radius * sin(angle)
		
		# 将按钮放置在以菜单中心为圆心的圆周上
		button.position = (Vector2(x, y) - (button.size / 2)) + (size / 2)
		
		# 连接信号，并将此按钮对应的Upgrade资源绑定给处理函数
		button.pressed.connect(_on_button_pressed.bind(upgrade_res))
	
	# 在所有子节点都添加完毕后，延迟调用位置调整函数
	# 这能确保菜单的最终尺寸已经被计算出来
	call_deferred("_adjust_position")

# 按钮点击处理函数
func _on_button_pressed(upgrade: Upgrade):
	SoundManager.play_sfx("ui_accept") # 播放点击升级按钮音效
	# 菜单的工作只是发出信号，告知哪个升级被选中了。
	# 所有游戏逻辑（花钱、应用升级）都由上层管理者（GameManager）处理。
	emit_signal("upgrade_selected", upgrade)

# --- 私有方法 ---

func _adjust_position():
	# 再次等待一帧可以进一步提高获取正确尺寸的稳定性
	await get_tree().process_frame

	var screen_size = get_viewport().get_visible_rect().size
	
	# --- 手动计算所有子节点的真实边界框 ---
	var child_bounds = Rect2()
	var first_child = true
	for child in get_children():
		if not child is Control: continue
		
		var rect = child.get_rect() # 获取子节点相对于自己的矩形
		rect.position += child.position # 将其位置转换为相对于父节点的坐标
		
		if first_child:
			child_bounds = rect
			first_child = false
		else:
			child_bounds = child_bounds.merge(rect)
	
	# 如果没有子节点，为避免出错直接返回
	if first_child:
		return
	# ------------------------------------------

	# --- 使用正确的边界框和偏移来计算和限制位置 ---
	var menu_size = child_bounds.size
	# 菜单的有效视觉位置 = 节点原点 + 计算出的边界框左上角偏移
	var effective_pos = global_position + child_bounds.position

	# 将有效位置限制在屏幕范围内
	effective_pos.x = clamp(effective_pos.x, 0, screen_size.x - menu_size.x)
	effective_pos.y = clamp(effective_pos.y, 0, screen_size.y - menu_size.y)
	
	# 根据被限制后的有效位置，反推出节点原点应该在的位置
	global_position = effective_pos - child_bounds.position
