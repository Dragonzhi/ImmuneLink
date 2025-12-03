extends Node

const BridgeUpgradeMenuScene = preload("res://scenes/ui/BridgeUpgradeMenu.tscn")
const BridgeUpgradeMenu = preload("res://scenes/ui/BridgeUpgradeMenu.gd") # Add this line

@export var overlay_path: NodePath
@export var ui_layer_path: NodePath
@export var fade_duration: float = 0.2
@export var attack_upgrade_cost: int = 20 # Cost for attack upgrade

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
