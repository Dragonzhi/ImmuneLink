extends Control

# --- 节点引用 ---
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var level_buttons_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/LevelButtonsContainer

# --- 可配置变量 ---
@export var total_levels: int = 6
@export var main_game_scene_path: String = "res://scenes/main/Main.tscn"
@export var main_menu_scene_path: String = "res://scenes/world/MainMenu.tscn"


func _ready() -> void:
	# --- 连接信号 ---
	back_button.pressed.connect(_on_back_button_pressed)
	
	# --- 动态生成关卡按钮 ---
	# 先清空容器，以防在编辑器里误放了占位符
	for child in level_buttons_container.get_children():
		child.queue_free()
	
	# 循环创建按钮
	for i in range(total_levels):
		var level_number = i + 1
		var button = Button.new()
		button.text = "任务 %d" % level_number
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 8)
		button.custom_minimum_size = Vector2(50, 10)
		# 连接按钮的点击信号，并绑定关卡编号作为参数
		button.pressed.connect(Callable(self, "_on_level_button_pressed").bind(level_number))
		
		level_buttons_container.add_child(button)


# --- 信号处理函数 ---

func _on_back_button_pressed() -> void:
	if SceneManager:
		SceneManager.change_scene_to_file(main_menu_scene_path)

func _on_level_button_pressed(level_number: int) -> void:
	print("选择了关卡 %d" % level_number)
	if SceneManager:
		# 目前所有按钮都先跳转到同一个主游戏场景
		match level_number:
			1:
				SceneManager.change_scene_to_file("res://scenes/levels/level01/Level01.tscn")
			2:
				SceneManager.change_scene_to_file("res://scenes/levels/level02/Level02.tscn")
			3:
				SceneManager.change_scene_to_file("res://scenes/levels/level03/Level03.tscn")
			4:
				SceneManager.change_scene_to_file("res://scenes/levels/level04/Level04.tscn")
