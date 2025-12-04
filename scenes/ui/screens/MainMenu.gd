extends Control

func _on_start_button_pressed():
	# 使用我们创建的SceneManager来切换到关卡选择界面
	# 注意：LevelSelect.tscn 此时还不存在，我们稍后会创建它
	SceneManager.change_scene("res://scenes/ui/screens/LevelSelect.tscn")

func _on_quit_button_pressed():
	# 退出游戏
	get_tree().quit()
