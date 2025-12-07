# DialogueBox.gd
class_name DialogueBox
extends CanvasLayer

## 对话框UI的控制器，负责显示单句对话、角色信息和打字机效果。

signal line_finished_displaying() # 当一句话显示完成时发出信号

# UI节点引用
@onready var name_label: Label = %NameLabel
@onready var text_label: Label = %TextLabel
@onready var portrait_rect: TextureRect = %PortraitRect
@onready var continue_indicator: Node = %ContinueIndicator # 提示玩家继续的图标

@export var characters_per_second: float = 50.0 # 打字机速度

var _current_text: String = ""
var _display_text: String = ""
var _text_display_timer: Timer
var _is_displaying: bool = false

func _ready() -> void:
	print("[DialogueBox] DEBUG: _ready called.")
	print("  - Checking name_label... Is it null? ", name_label == null)
	print("  - Checking text_label... Is it null? ", text_label == null)
	
	# 初始化时隐藏自己
	visible = false
	
	# 创建用于打字机效果的Timer
	_text_display_timer = Timer.new()
	_text_display_timer.one_shot = true
	_text_display_timer.process_mode = Node.PROCESS_MODE_ALWAYS # 确保暂停时也能运行
	add_child(_text_display_timer)
	_text_display_timer.timeout.connect(_on_text_display_timer_timeout)


## 公共方法：开始显示一句新的对话
func show_line(dialogue_line: Dictionary):
	SoundManager.play_sfx("ui_say") # 播放音效
	visible = true
	_is_displaying = true
	
	# 更新UI
	name_label.text = dialogue_line.get("name", "")
	_current_text = dialogue_line.get("text", "...")
	
	var portrait = dialogue_line.get("portrait")
	if portrait is Texture2D:
		portrait_rect.texture = portrait
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false

	# 重置文本和指示器
	_display_text = ""
	text_label.text = ""
	continue_indicator.visible = false
	
	# 开始打字机效果
	_start_typewriter()


## 公共方法：如果正在显示，立即完成显示
func finish_displaying():
	if not _is_displaying:
		return
		
	# 停止计时器并显示全部文本
	_text_display_timer.stop()
	text_label.text = _current_text
	_is_displaying = false
	continue_indicator.visible = true
	emit_signal("line_finished_displaying")


## 公共方法：隐藏对话框
func hide_box():
	visible = false


func is_displaying() -> bool:
	return _is_displaying

# --- 私有方法 ---

func _start_typewriter():
	_on_text_display_timer_timeout() # 立即显示第一个字符

func _on_text_display_timer_timeout():
	if len(_display_text) >= len(_current_text):
		finish_displaying()
		return

	# 添加下一个字符
	var next_char_index = len(_display_text)
	_display_text += _current_text[next_char_index]
	text_label.text = _display_text
	
	# 设置下一次显示的时间
	_text_display_timer.start(1.0 / characters_per_second)
