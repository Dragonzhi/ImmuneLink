extends ColorRect

var ui_manager: Node

func _ready() -> void:
	ui_manager = get_node("/root/Main/UIManager")
	if not ui_manager:
		printerr("Overlay Error: UIManager not found!")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if ui_manager:
			ui_manager.close_upgrade_menu()
			get_viewport().set_input_as_handled()
