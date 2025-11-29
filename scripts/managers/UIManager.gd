extends Node

const BridgeUpgradeMenuScene = preload("res://scenes/ui/BridgeUpgradeMenu.tscn")

@export var overlay_path: NodePath
@export var ui_layer_path: NodePath

var overlay: ColorRect
var ui_layer: CanvasLayer
var current_menu: Control = null

func _ready() -> void:
	overlay = get_node(overlay_path)
	ui_layer = get_node(ui_layer_path)
	if not overlay:
		printerr("UIManager Error: Overlay node not found at path: %s" % overlay_path)
	if not ui_layer:
		printerr("UIManager Error: UI Layer node not found at path: %s" % ui_layer_path)

func open_upgrade_menu(bridge: Bridge):
	# If a menu is already open, close it first.
	if current_menu:
		close_upgrade_menu()

	# Show the overlay
	if overlay:
		overlay.visible = true

	# Create and position the menu
	current_menu = BridgeUpgradeMenuScene.instantiate()
	if ui_layer:
		ui_layer.add_child(current_menu)
	else:
		get_tree().get_root().add_child(current_menu) # Fallback
		
	current_menu.global_position = bridge.global_position

	# Connect to the menu's signals if needed
	# current_menu.upgrade_selected.connect(_on_upgrade_selected)

func close_upgrade_menu():
	if current_menu:
		current_menu.queue_free()
		current_menu = null
	
	if overlay:
		overlay.visible = false

# This function will be connected to the bridge's 'bridge_selected' signal.
func _on_bridge_selected(bridge: Bridge):
	open_upgrade_menu(bridge)
