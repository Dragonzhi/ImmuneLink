extends Control

var result_text: String = ""
var stats_text: String = ""
var next_level_scene: String = "res://scenes/main/Main.tscn" # 默认重新开始当前关卡

func _ready():
	_update_ui()

func _update_ui():
	$CenterContainer/VBoxContainer/ResultLabel.text = result_text
	$CenterContainer/VBoxContainer/StatsLabel.text = stats_text

func set_end_screen_data(is_win: bool, level_stats: Dictionary = {}):
	if is_win:
		result_text = "胜利！"
	else:
		result_text = "失败！"
	
	stats_text = "得分: %d\n时间: %s" % [level_stats.get("score", 0), level_stats.get("time", "00:00")]
	_update_ui()

func _on_restart_button_pressed():
	# 重新开始当前关卡
	SceneManager.change_scene(next_level_scene)

func _on_main_menu_button_pressed():
	# 返回主菜单
	SceneManager.change_scene("res://scenes/ui/screens/MainMenu.tscn")

