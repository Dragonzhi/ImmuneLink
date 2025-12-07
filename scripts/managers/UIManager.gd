extends Node

const BridgeUpgradeMenuScene = preload("res://scenes/ui/BridgeUpgradeMenu.tscn")
const BridgeUpgradeMenu = preload("res://scenes/ui/BridgeUpgradeMenu.gd") # Add this line

@export var overlay_path: NodePath
@export var ui_layer_path: NodePath
@export var fade_duration: float = 0.2
@export var theme: Theme

var overlay: ColorRect
var ui_layer: CanvasLayer
var current_menu: BridgeUpgradeMenu = null # 明确类型为 BridgeUpgradeMenu
var tween: Tween

func _ready() -> void:
	overlay = get_node(overlay_path)
	ui_layer = get_node(ui_layer_path)
	if not overlay:
		printerr("UIManager Error: Overlay node not found at path: %s" % overlay_path)
	if not ui_layer:
		printerr("UIManager Error: UI Layer node not found at path: %s" % ui_layer_path)
	
	# Initialize overlay to be fully transparent
	if overlay:
		var initial_color = overlay.color
		overlay.color = Color(initial_color.r, initial_color.g, initial_color.b, 0.0)
		overlay.visible = false

@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var over_label: Label = $"../UILayer/OverPanelContainer/CenterContainer/PanelContainer/overLabel"

# --- 新增：游戏结束横幅 ---
func show_game_over_banner(message: String):
	SoundManager.play_sfx("game_over") # 播放游戏结束音效
	animation_player.play("Win")
	over_label.text = message
	## 创建一个半透明的灰色背景条
	#var banner_bg = PanelContainer.new()
	#banner_bg.process_mode = Node.PROCESS_MODE_ALWAYS # 确保暂停时可见
	#banner_bg.self_modulate = Color(0.2, 0.2, 0.2, 0.8) # 半透明深灰色
	## 设置大小和位置
	#banner_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	#banner_bg.size = Vector2(400, 80) # 横幅的尺寸
	#banner_bg.position = -banner_bg.size / 2 # 居中
#
	## 创建文本标签
	#var banner_label = Label.new()
	#banner_label.process_mode = Node.PROCESS_MODE_ALWAYS
	#banner_label.theme = theme # 使用导出的主题
	#banner_label.add_theme_font_size_override("font_size", 24) # 正确的Godot 4语法
	#banner_label.text = message
	#banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	#banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#
	#banner_bg.add_child(banner_label)
	#
	## 将横幅添加到UI层
	## 为了确保它在屏幕中央，我们将其添加到一个CenterContainer中
	#var center_container = CenterContainer.new()
	#center_container.process_mode = Node.PROCESS_MODE_ALWAYS
	#center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#center_container.add_child(banner_bg)
#
	#ui_layer.add_child(center_container)

func open_upgrade_menu(upgrades: Array[Upgrade], bridge: Bridge):
	if tween and tween.is_running():
		tween.kill()
	
	if current_menu: # 如果菜单已经打开，先关闭
		close_upgrade_menu()

	# Show overlay and create menu
	overlay.visible = true
	current_menu = BridgeUpgradeMenuScene.instantiate() as BridgeUpgradeMenu # 实例化时转换为正确类型
	# 调用菜单的新方法来动态填充升级按钮
	current_menu.populate_menu(upgrades, bridge)
	
	current_menu.modulate = Color(1, 1, 1, 0) # Start transparent
	ui_layer.add_child(current_menu)
	current_menu.global_position = bridge.global_position

	# 连接菜单发出的新的、更通用的升级信号
	current_menu.upgrade_selected.connect(_on_upgrade_chosen)

	# Create fade-in tween
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.5, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_menu, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		
		# --- 新增：在退出前，强制关闭所有对话 ---
		if DialogueManager and DialogueManager.has_method("force_stop_all_dialogues"):
			DialogueManager.force_stop_all_dialogues()
		
		get_tree().paused = false # 确保游戏未暂停
		if current_menu and current_menu.is_visible(): # 如果升级菜单打开了，先关闭
			close_upgrade_menu()
		SceneManager.change_scene_to_file("res://scenes/ui/screens/LevelSelect.tscn")

func close_upgrade_menu():
	if not current_menu:
		return

	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_menu, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)

	# After the fade-out, clean up the nodes
	tween.tween_callback(_on_fade_out_finished)

func _on_fade_out_finished():
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	if overlay:
		overlay.visible = false

# 处理来自 BridgeUpgradeMenu 的新信号
func _on_upgrade_chosen(upgrade: Upgrade):
	if not current_menu or not is_instance_valid(current_menu.selected_bridge):
		return
		
	var bridge = current_menu.selected_bridge
	print("UIManager 收到升级选择: %s, 应用于桥梁: %s" % [upgrade.upgrade_name, bridge.grid_pos])
	
	# 将升级请求转发给 GameManager
	GameManager.request_upgrade(upgrade, bridge)

	# 无论升级成功与否，都关闭菜单
	close_upgrade_menu()

# --- 公共重置函数 ---
func reset_ui():
	# 强制停止所有UI动画
	if tween and tween.is_running():
		tween.kill()
	
	# 强制释放菜单
	if current_menu and is_instance_valid(current_menu):
		current_menu.queue_free()
		current_menu = null
	
	# 强制隐藏遮罩
	if overlay:
		overlay.visible = false
