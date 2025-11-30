extends Control

const Bridge = preload("res://scenes/bridge/bridge.gd") # Add this line

# 用于配置按钮外观和行为
@export var button_scene: PackedScene # 如果有自定义按钮场景，可以在这里设置
@export var button_radius: float = 60.0
@export var button_count: int = 4
@export var attack_upgrade_button_index: int = 0 # 哪个按钮用于攻击升级

# 信号，当按钮被点击时发出
signal upgrade_selected(index: int, bridge: Bridge)

var selected_bridge: Bridge = null # 对当前选中的桥梁的引用

func _ready() -> void:
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
			button = Button.new()
			button.text = "升级 %s" % (i + 1)
			button.size = Vector2(40, 20)

		add_child(button)
		
		var x = radius * cos(angle)
		var y = radius * sin(angle)
		
		button.position = Vector2(x, y) - (button.size / 2)
		
		button.pressed.connect(_on_button_pressed.bind(i))

# 按钮点击处理函数
func _on_button_pressed(index: int):
	# The menu's only job is to signal which button was pressed.
	# All game logic (spending resources, applying upgrades) is handled by UIManager.
	emit_signal("upgrade_selected", index, selected_bridge)
