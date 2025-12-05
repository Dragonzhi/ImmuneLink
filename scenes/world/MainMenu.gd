extends Control

func _on_start_button_pressed():
	# 使用我们创建的SceneManager来切换到主游戏场景
	SceneManager.change_scene_to_file("res://scenes/main/Main.tscn")

func _on_quit_button_pressed():
	# 退出游戏
	get_tree().quit()
