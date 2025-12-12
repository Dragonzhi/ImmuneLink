extends Control

# --- 节点引用 ---
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var title: Label = $MarginContainer/VBoxContainer/Title
@onready var mode_select_container: VBoxContainer = $MarginContainer/VBoxContainer/ModeSelectContainer
@onready var campaign_button: Button = $MarginContainer/VBoxContainer/ModeSelectContainer/CampaignButton
@onready var custom_button: Button = $MarginContainer/VBoxContainer/ModeSelectContainer/CustomButton
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var level_buttons_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/LevelButtonsContainer

# --- 可配置变量 ---
@export var level_names: Array[String] # 所有关卡的名称列表
@export var level_scene_paths: Array[String] # 与level_names对应的关卡场景路径列表
@export var main_menu_scene_path: String = "res://scenes/world/MainMenu.tscn"
@export var level_load_scene_path: String = "res://scenes/levels/load_level/Level_load.tscn"

# --- 内部状态 ---
var _is_mode_select_visible: bool = true

func _ready() -> void:
	DebugManager.register_category("LevelSelect", false)

	# --- 连接信号 ---
	back_button.pressed.connect(_on_back_button_pressed)
	campaign_button.pressed.connect(_on_campaign_button_pressed)
	custom_button.pressed.connect(_on_custom_button_pressed)

	# --- 设置初始状态 ---
	_show_mode_select_view()


# --- 视图管理 ---

func _show_mode_select_view() -> void:
	_is_mode_select_visible = true
	
	title.text = "选择模式"
	back_button.text = " < 主菜单 "
	
	mode_select_container.show()
	scroll_container.hide()
	
	_clear_level_buttons()

func _show_level_list_view(list_title: String) -> void:
	_is_mode_select_visible = false
	
	title.text = list_title
	back_button.text = " < 返回 "
	
	mode_select_container.hide()
	scroll_container.show()
	
	_clear_level_buttons()

# --- 信号处理函数 ---

func _on_back_button_pressed() -> void:
	SoundManager.play_sfx("ui_cancel")
	if _is_mode_select_visible:
		if SceneManager:
			SceneManager.change_scene_to_file(main_menu_scene_path)
	else:
		_show_mode_select_view()

func _on_campaign_button_pressed() -> void:
	SoundManager.play_sfx("ui_accept")
	_show_level_list_view("选择关卡")
	_populate_campaign_levels()

func _on_custom_button_pressed() -> void:
	SoundManager.play_sfx("ui_accept")
	_show_level_list_view("选择自定义关卡")
	_populate_custom_levels()

func _on_level_button_pressed(index: int) -> void:
	SoundManager.play_sfx("ui_accept")
	
	if index < 0 or index >= level_scene_paths.size():
		printerr("LevelSelect: 无效的关卡选择索引: %s" % index)
		return

	var selected_scene_path = level_scene_paths[index]
	DebugManager.dprint("LevelSelect", "选择了预设关卡 %s" % selected_scene_path)
	
	if SceneManager:
		SceneManager.change_scene_to_file(selected_scene_path)
	else:
		printerr("LevelSelect: SceneManager 未找到！")

func _on_custom_level_button_pressed(json_path: String) -> void:
	SoundManager.play_sfx("ui_accept")
	DebugManager.dprint("LevelSelect", "选择了自定义关卡 %s" % json_path)
	
	# 将选择的JSON路径存储到GameManager中，以便LevelLoader加载
	if GameManager:
		GameManager.custom_level_json_path = json_path
		if SceneManager:
			SceneManager.change_scene_to_file(level_load_scene_path)
		else:
			printerr("LevelSelect: SceneManager 未找到！")
	else:
		printerr("LevelSelect: GameManager 未找到！")


# --- 关卡列表生成 ---

func _clear_level_buttons() -> void:
	for child in level_buttons_container.get_children():
		child.queue_free()

func _populate_campaign_levels() -> void:
	if level_names.size() != level_scene_paths.size():
		printerr("LevelSelect: level_names 和 level_scene_paths 的数量不匹配！")
		return
	
	for i in range(level_names.size()):
		_create_level_button(level_names[i], Callable(self, "_on_level_button_pressed").bind(i))

func _populate_custom_levels() -> void:
	var custom_levels: Array[String] = []
	
	# 优先检查可执行文件目录下的levels/
	var exe_dir = OS.get_executable_path().get_base_dir()
	var custom_dir_path = exe_dir.path_join("levels")
	custom_levels = _find_json_files(custom_dir_path)

	# 如果exe目录没有，则检查res://下的内置数据
	if custom_levels.is_empty():
		custom_levels = _find_json_files("res://levels/data/")
	
	if custom_levels.is_empty():
		var label = Label.new()
		label.text = "没有找到自定义关卡。\n请将 *.json 文件放入游戏目录的 'levels' 文件夹中。"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_buttons_container.add_child(label)
		return

	for json_path in custom_levels:
		var file_name = json_path.get_file().get_basename()
		_create_level_button(file_name, Callable(self, "_on_custom_level_button_pressed").bind(json_path))

func _find_json_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() == "json":
				files.append(path.path_join(file_name))
			file_name = dir.get_next()
	else:
		DebugManager.dprint("LevelSelect", "无法访问目录: %s" % path)
	return files

func _create_level_button(name: String, on_pressed: Callable) -> void:
	var button = Button.new()
	button.text = name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 8)
	button.custom_minimum_size = Vector2(50, 10)
	button.pressed.connect(on_pressed)
	level_buttons_container.add_child(button)
