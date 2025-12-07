# BaseButton.gd
extends Button

func _ready() -> void:
	# 连接按钮自身的 pressed 信号到 _on_pressed 函数
	# 我们使用 connect 函数而不是在编辑器中连接，以确保这个逻辑是自包含的。
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# 播放一个通用的UI点击音效
	SoundManager.play_sfx("ui_accept")
