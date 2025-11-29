extends Control

# 用于配置按钮外观和行为
@export var button_scene: PackedScene # 如果有自定义按钮场景，可以在这里设置
@export var button_radius: float = 60.0
@export var button_count: int = 4

# 信号，当按钮被点击时发出
signal upgrade_selected(index: int)

func _ready() -> void:
	# 将 Control 节点的中心点与它的位置对齐
	pivot_offset = size / 2
	generate_buttons(button_count, button_radius)

# 动态创建并布置按钮
func generate_buttons(count: int, radius: float):
	if count <= 0:
		return

	var angle_step = (2 * PI) / count

	for i in range(count):
		var angle = angle_step * i
		
		var button: Button
		if button_scene:
			button = button_scene.instantiate()
		else:
			# 如果没有提供自定义按钮场景，则创建一个默认按钮
			button = Button.new()
			button.text = "升级 %s" % (i + 1)
			button.size = Vector2(40, 20) # 设置默认大小

		add_child(button)
		
		# 计算按钮位置
		var x = radius * cos(angle)
		var y = radius * sin(angle)
		
		# 将按钮位置设置为相对于Control中心的偏移量
		# 我们需要减去按钮自身尺寸的一半来使其中心对齐
		button.position = Vector2(x, y) - (button.size / 2)
		
		# 连接按钮的pressed信号
		# 我们传递按钮的索引 i 以便区分是哪个按钮被点击了
		button.pressed.connect(_on_button_pressed.bind(i))

# 按钮点击处理函数
func _on_button_pressed(index: int):
	print("点击了升级按钮，索引: ", index)
	emit_signal("upgrade_selected", index)
	# 在这里可以添加关闭菜单的逻辑，或者让父节点处理
