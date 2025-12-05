extends Control

# 注意：下一个关卡的场景路径可以在未来被更复杂的逻辑（如关卡数据）动态设置
var next_level_scene: String = "res://scenes/main/Main.tscn" 

func _ready():
	# 从SceneManager获取胜负数据和统计数据
	var data = SceneManager.get_end_screen_data()
	var is_win = data.get("is_win", false)
	var stats = data.get("stats", {})
	
	if is_win:
		$CenterContainer/VBoxContainer/ResultLabel.text = "胜利！"
	else:
		$CenterContainer/VBoxContainer/ResultLabel.text = "失败！"
	
	$CenterContainer/VBoxContainer/StatsLabel.text = "得分: %d\n时间: %s" % [stats.get("score", 0), stats.get("time", "00:00")]


func _on_restart_button_pressed():
	# 重新开始当前关卡
	SceneManager.change_scene(next_level_scene)

func _on_main_menu_button_pressed():
	# 返回主菜单
	SceneManager.change_scene("res://scenes/ui/screens/MainMenu.tscn")

