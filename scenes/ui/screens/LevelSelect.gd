extends Control

func _on_level_1_button_pressed():
	# 切换到主游戏场景
	SceneManager.change_scene("res://scenes/main/Main.tscn")

func _on_back_button_pressed():
	# 返回主菜单
	SceneManager.change_scene("res://scenes/ui/screens/MainMenu.tscn")
