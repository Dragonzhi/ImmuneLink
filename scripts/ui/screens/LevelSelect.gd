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
@export var level_names: Array[String]
@export var level_scene_paths: Array[String]
@export var main_menu_scene_path: String = "res://scenes/world/MainMenu.tscn"
@export var level_load_scene_path: String = "res://scenes/levels/load_level/Level_load.tscn"

# --- 内部状态 ---
var _is_mode_select_visible: bool = true
var _is_transitioning: bool = false # 防止在动画期间重复点击

# --- 常量 ---
const FADE_DURATION := 0.2
const STAGGER_DELAY := 0.05

func _ready() -> void:
	DebugManager.register_category("LevelSelect", false)

	# --- 连接信号 ---
	back_button.pressed.connect(_on_back_button_pressed)
	campaign_button.pressed.connect(_on_campaign_button_pressed)
	custom_button.pressed.connect(_on_custom_button_pressed)

	# --- 设置初始状态 ---
	mode_select_container.hide()
	scroll_container.hide()
	
	# 异步执行初始动画
	_switch_to_mode_view(false)


# --- 视图切换核心逻辑 ---

func _switch_to_mode_view(from_level_list: bool) -> void:
	if _is_transitioning: return
	_is_transitioning = true
	
	_is_mode_select_visible = true
	title.text = "选择模式"
	back_button.text = " < 主菜单 "
	
	if from_level_list:
		await _animate_view(scroll_container, level_buttons_container, false).finished
		_clear_level_buttons()

	await _animate_view(mode_select_container, mode_select_container, true).finished
	_is_transitioning = false

func _switch_to_level_view(list_title: String, populate_callable: Callable) -> void:
	if _is_transitioning: return
	_is_transitioning = true

	_is_mode_select_visible = false
	title.text = list_title
	back_button.text = " < 返回 "
	
	await _animate_view(mode_select_container, mode_select_container, false).finished

	populate_callable.call()
	await _animate_view(scroll_container, level_buttons_container, true).finished
	
	_is_transitioning = false

# --- 信号处理函数 ---

func _on_back_button_pressed() -> void:
	if _is_transitioning: return
	
	SoundManager.play_sfx("ui_cancel")
	if _is_mode_select_visible:
		_is_transitioning = true
		await _animate_view(mode_select_container, mode_select_container, false).finished
		if SceneManager:
			SceneManager.change_scene_to_file(main_menu_scene_path)
	else:
		_switch_to_mode_view(true)

func _on_campaign_button_pressed() -> void:
	SoundManager.play_sfx("ui_accept")
	_switch_to_level_view("选择关卡", Callable(self, "_populate_campaign_levels"))

func _on_custom_button_pressed() -> void:
	SoundManager.play_sfx("ui_accept")
	_switch_to_level_view("选择自定义关卡", Callable(self, "_populate_custom_levels"))

func _on_level_button_pressed(index: int) -> void:
	SoundManager.play_sfx("ui_accept")
	if index < 0 or index >= level_scene_paths.size(): return
	var selected_scene_path = level_scene_paths[index]
	if SceneManager: SceneManager.change_scene_to_file(selected_scene_path)

func _on_custom_level_button_pressed(json_path: String) -> void:
	SoundManager.play_sfx("ui_accept")
	if GameManager:
		GameManager.custom_level_json_path = json_path
		if SceneManager: SceneManager.change_scene_to_file(level_load_scene_path)

# --- 动画辅助函数 ---

func _animate_view(view_container: CanvasItem, child_container: CanvasItem, fade_in: bool) -> Tween:
	var tween = create_tween().set_parallel()
	var target_alpha = 1.0 if fade_in else 0.0

	# 1. 动画化主容器
	if fade_in:
		view_container.modulate.a = 0.0
		view_container.show()
	tween.tween_property(view_container, "modulate:a", target_alpha, FADE_DURATION)

	# 2. 交错动画化所有子节点
	var children = child_container.get_children()
	for i in range(children.size()):
		var child = children[i]
		if not child is CanvasItem: continue
		
		if fade_in:
			child.modulate.a = 0.0
		tween.tween_property(child, "modulate:a", target_alpha, FADE_DURATION).set_delay(i * STAGGER_DELAY)
	
	if not fade_in:
		tween.chain().tween_callback(view_container.hide)
		
	return tween

# --- 关卡列表生成 ---

func _clear_level_buttons() -> void:
	for child in level_buttons_container.get_children():
		child.queue_free()

func _populate_campaign_levels() -> void:
	if level_names.size() != level_scene_paths.size(): return
	for i in range(level_names.size()):
		_create_level_button(level_names[i], Callable(self, "_on_level_button_pressed").bind(i))

func _populate_custom_levels() -> void:
	var custom_levels := _find_json_files("user://levels/")
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
