extends Control

# --- 节点引用 ---
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var level_buttons_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/LevelButtonsContainer

# --- 可配置变量 ---
# @export var total_levels: int = 6 # 不再使用
@export var level_configs: Array[LevelConfig] # 所有关卡的配置列表
@export var level_scene_paths: Array[String] # 与level_configs对应的关卡场景路径列表
@export var main_menu_scene_path: String = "res://scenes/world/MainMenu.tscn"

func _ready() -> void:
	DebugManager.register_category("LevelSelect", false) # 注册调试类别
	
	# 确保配置和场景路径数量匹配
	if level_configs.size() != level_scene_paths.size():
		printerr("LevelSelect: level_configs 和 level_scene_paths 的数量不匹配！")
		return

	# --- 连接信号 ---
	back_button.pressed.connect(_on_back_button_pressed)
	
	# --- 动态生成关卡按钮 ---
	# 先清空容器，以防在编辑器里误放了占位符
	for child in level_buttons_container.get_children():
		child.queue_free()
	
	# 循环创建按钮
	for i in range(level_configs.size()):
		var level_config = level_configs[i]
		
		var button = Button.new()
		button.text = "%s" % level_config.level_name # 使用LevelConfig中的关卡名
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 8)
		button.custom_minimum_size = Vector2(50, 10)
		# 连接按钮的点击信号，并绑定关卡索引作为参数
		button.pressed.connect(Callable(self, "_on_level_button_pressed").bind(i)) # 绑定索引
		
		level_buttons_container.add_child(button)


# --- 信号处理函数 ---

func _on_back_button_pressed() -> void:
	SoundManager.play_sfx("ui_cancel")
	if SceneManager:
		SceneManager.change_scene_to_file(main_menu_scene_path)

func _on_level_button_pressed(index: int) -> void: # 接收索引
	SoundManager.play_sfx("ui_accept")
	
	if index < 0 or index >= level_configs.size():
		printerr("LevelSelect: 无效的关卡选择索引: %s" % index)
		return

	var selected_level_config = level_configs[index]
	var selected_scene_path = level_scene_paths[index]
	
	DebugManager.dprint("LevelSelect", "选择了关卡 %s" % selected_level_config.level_name) # 更新调试信息
	
	if GameManager and SceneManager:
		GameManager.set_next_level_config(selected_level_config) # 将配置传递给GameManager
		SceneManager.change_scene_to_file(selected_scene_path) # 切换到对应关卡场景
	else:
		printerr("LevelSelect: GameManager 或 SceneManager 未找到！")
