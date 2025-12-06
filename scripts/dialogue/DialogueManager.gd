# DialogueManager.gd
extends Node

## 全局对话管理器 (Autoload/Singleton)
## 负责处理对话逻辑流程、UI交互和游戏状态的暂停/恢复。

signal dialogue_started()
signal dialogue_finished()

const DialogueBoxScene = preload("res://scenes/ui/dialogue/DialogueBox.tscn")

var _dialogue_box: CanvasLayer = null # 初始化为null，以便进行延迟初始化
var _dialogue_queue: Array[DialogueResource] = []
var _current_dialogue: DialogueResource = null
var _current_line_index: int = -1
var _is_active: bool = false

func _ready() -> void:
	# _ready函数中不再进行实例化，等待第一次调用时再执行
	pass


func _unhandled_input(event: InputEvent) -> void:
	# 如果对话不处于激活状态，或者事件已经被处理，则忽略
	if not _is_active or get_viewport().is_input_handled():
		return

	# 监听玩家的“继续”输入 (键盘或鼠标点击)
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		get_viewport().set_input_as_handled()
		_advance_dialogue()


## 公共API：开始一段对话，或者将其加入队列
func start_dialogue(resource: DialogueResource):
	# 确保传入的资源有效
	if not resource or resource.dialogue_lines.is_empty():
		printerr("DialogueManager: 尝试开始一个无效的或空的对话资源。")
		return

	# 将对话加入队列
	_dialogue_queue.push_back(resource)
	
	# 如果当前没有对话在进行，则立即开始处理队列
	if not _is_active:
		_process_dialogue_queue()


func is_active() -> bool:
	return _is_active
	

# --- 私有方法 ---

func _process_dialogue_queue():
	if _is_active or _dialogue_queue.is_empty():
		return
		
	# 延迟初始化：确保对话框UI存在且已就绪
	if not is_instance_valid(_dialogue_box):
		print("[DialogueManager] DEBUG: _dialogue_box is invalid. Creating a new one.")
		_dialogue_box = DialogueBoxScene.instantiate()
		get_tree().root.add_child(_dialogue_box)
		_dialogue_box.line_finished_displaying.connect(_on_line_finished)
		# 关键：等待一帧，确保新节点的 _ready() 函数被执行
		await get_tree().process_frame
		print("[DialogueManager] DEBUG: New _dialogue_box is now ready.")
	
	# 从队列中取出下一个对话开始
	var next_dialogue = _dialogue_queue.pop_front()
	_begin_dialogue(next_dialogue)


func _begin_dialogue(resource: DialogueResource):
	_is_active = true
	_current_dialogue = resource
	_current_line_index = -1
	emit_signal("dialogue_started")
	_advance_dialogue()


func _advance_dialogue():
	# 如果当前行还在播放打字机效果，则立即完成它
	if _dialogue_box.is_displaying():
		_dialogue_box.finish_displaying()
		return

	# 移动到下一行
	_current_line_index += 1

	if _current_line_index < _current_dialogue.dialogue_lines.size():
		# 如果还有下一行，显示它
		var line_data = _current_dialogue.dialogue_lines[_current_line_index]
		_dialogue_box.show_line(line_data)
	else:
		# 如果所有行都已显示完毕，结束对话
		_end_dialogue()


func _end_dialogue():
	_is_active = false
	_current_dialogue = null
	_dialogue_box.hide_box()
	emit_signal("dialogue_finished")

	# 检查队列中是否还有待处理的对话
	if not _dialogue_queue.is_empty():
		_process_dialogue_queue()


func _on_line_finished():
	# 这一行显示完成，可以进行下一步操作（例如，等待玩家输入）
	# 目前的逻辑是，玩家的任何输入都会调用 _advance_dialogue
	pass
