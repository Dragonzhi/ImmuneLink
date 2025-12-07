extends Control

func _ready() -> void:
	# 在主界面加载时播放背景音乐
	SoundManager.play_music("main")

func _on_start_button_pressed():
	# 使用我们创建的SceneManager来切换到关卡选择界面
	SceneManager.change_scene_to_file("res://scenes/ui/screens/LevelSelect.tscn")

func _on_quit_button_pressed():
	# 退出游戏
	get_tree().quit()
