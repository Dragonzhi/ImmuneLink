extends Control

# 该脚本用于控制结束画面
# 它会显示最终的分数和所用时间，并提供返回主菜单的选项

@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	menu_button.pressed.connect(_on_menu_button_pressed)
	
	# 从SceneManager获取数据并更新UI
	# 我们假设SceneManager有一个名为scene_data的字典来传递数据
	if SceneManager.scene_data:
		var score = SceneManager.scene_data.get("score", 0)
		var time_elapsed = SceneManager.scene_data.get("time", "00:00")
		score_label.text = str(score)
		time_label.text = time_elapsed
	
	# 清理数据，以免影响下一次场景切换
	SceneManager.scene_data = {}


func _on_menu_button_pressed() -> void:
	# 让SceneManager切换回主菜单
	# 假设主菜单场景路径为 "res://scenes/world/MainMenu.tscn"
	SceneManager.change_scene_to_file("res://scenes/world/MainMenu.tscn")
