extends Node

const BridgeUpgradeMenuScene = preload("res://scenes/ui/BridgeUpgradeMenu.tscn")

@export var overlay_path: NodePath
@export var ui_layer_path: NodePath
@export var fade_duration: float = 0.2

var overlay: ColorRect
var ui_layer: CanvasLayer
var current_menu: Control = null
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

func open_upgrade_menu(bridge: Bridge):
	if tween and tween.is_running():
		tween.kill()

	# Show overlay and create menu
	overlay.visible = true
	current_menu = BridgeUpgradeMenuScene.instantiate()
	current_menu.modulate = Color(1, 1, 1, 0) # Start transparent
	ui_layer.add_child(current_menu)
	current_menu.global_position = bridge.global_position

	# Create fade-in tween
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.5, fade_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(current_menu, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)

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

# This function will be connected to the bridge's 'bridge_selected' signal.
func _on_bridge_selected(bridge: Bridge):
	open_upgrade_menu(bridge)