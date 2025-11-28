extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 从性能监控器获取当前的每秒帧数(FPS)
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	# 更新Label的文本来显示FPS
	text = "FPS: " + str(fps)
