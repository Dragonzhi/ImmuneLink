extends Node

const BridgeUpgradeMenuScene = preload("res://scenes/ui/BridgeUpgradeMenu.tscn")
const BridgeUpgradeMenu = preload("res://scenes/ui/BridgeUpgradeMenu.gd")

signal feedback_requested(message: String)

@export var overlay_path: NodePath
@export var ui_layer_path: NodePath
@export var fade_duration: float = 0.2
@export var theme: Theme

var overlay: ColorRect
var ui_layer: CanvasLayer
var current_menu: BridgeUpgradeMenu = null
var tween: Tween

@onready var animation_player: AnimationPlayer = get_node_or_null("../AnimationPlayer")
@onready var over_label: Label = get_node_or_null("../UILayer/OverPanelContainer/CenterContainer/PanelContainer/overLabel")
@onready var pause_button: Button = get_node_or_null("../UILayer/GameUI/PauseButton")


func _ready() -> void:
	DebugManager.register_category("UIManager", false)
	overlay = get_node_or_null(overlay_path)
	ui_layer = get_node_or_null(ui_layer_path)
	if not overlay:
		printerr("UIManager Error: Overlay node not found at path: %s" % overlay_path)
	if not ui_layer:
		printerr("UIManager Error: UI Layer node not found at path: %s" % ui_layer_path)
	
	# Pause button setup
	if pause_button:
		pause_button.pressed.connect(_toggle_pause)
	else:
		printerr("UIManager Error: PauseButton not found.")
		
	# Initialize overlay to be fully transparent
	if overlay:
		var initial_color = overlay.color
		overlay.color = Color(initial_color.r, initial_color.g, initial_color.b, 0.0)
		overlay.visible = false


func request_feedback(message: String):
	emit_signal("feedback_requested", message)


func _toggle_pause() -> void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	
	if tween and tween.is_running(): tween.kill()
	tween = create_tween()
	
	if new_pause_state:
		# 暂停游戏
		overlay.show()
		tween.tween_property(overlay, "color:a", 0.5, fade_duration)
	else:
		# 继续游戏
		tween.tween_property(overlay, "color:a", 0.0, fade_duration)
		tween.chain().tween_callback(overlay.hide)


# --- 游戏结束横幅 ---
func show_game_over_banner(message: String):
	SoundManager.play_sfx("game_over") # 播放游戏结束音效
	if animation_player: animation_player.play("Win")
	if over_label: over_label.text = message

func open_upgrade_menu(upgrades: Array[Upgrade], bridge: Bridge):
	if tween and tween.is_running(): tween.kill()
	
	if current_menu and is_instance_valid(current_menu):
		current_menu.queue_free()

	overlay.visible = true
	current_menu = BridgeUpgradeMenuScene.instantiate() as BridgeUpgradeMenu
	current_menu.populate_menu(upgrades, bridge)
	current_menu.modulate = Color(1, 1, 1, 0)
	ui_layer.add_child(current_menu)
	current_menu.global_position = bridge.global_position
	current_menu.upgrade_selected.connect(_on_upgrade_chosen)

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.5, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_menu, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		
		if DialogueManager and DialogueManager.has_method("force_stop_all_dialogues"):
			DialogueManager.force_stop_all_dialogues()
		
		get_tree().paused = false # 确保游戏未暂停
		if current_menu and current_menu.is_visible():
			close_upgrade_menu()
		SceneManager.change_scene_to_file("res://scenes/ui/screens/LevelSelect.tscn")

func close_upgrade_menu():
	if not current_menu: return

	if tween and tween.is_running(): tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_menu, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_on_fade_out_finished)

func _on_fade_out_finished():
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	if overlay:
		overlay.visible = false

func _on_upgrade_chosen(upgrade: Upgrade):
	if not current_menu or not is_instance_valid(current_menu.selected_bridge): return
		
	var bridge = current_menu.selected_bridge
	GameManager.request_upgrade(upgrade, bridge)
	close_upgrade_menu()

func reset_ui():
	if tween and tween.is_running(): tween.kill()
	
	if current_menu and is_instance_valid(current_menu):
		current_menu.queue_free()
		current_menu = null
	
	if overlay:
		overlay.visible = false
