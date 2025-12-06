# TutorialManager.gd
class_name TutorialManager
extends Node

## 教程管理器，用于引导玩家完成教学关卡步骤。

@export var initial_dialogue: DialogueResource # 初始对话：如何连接管道
@export var post_connect_dialogue: DialogueResource # 连接管道后的对话：介绍敌人、升级等

var _wave_manager: WaveManager
var _waiting_for_blue_connection: bool = false
var _waiting_for_enemy_dialogue_end: bool = false

func _ready() -> void:
	# 确保全局Autoload存在
	#assert(Engine.has_singleton("ConnectionManager"), "ConnectionManager Autoload not found!")
	#assert(Engine.has_singleton("GameManager"), "GameManager Autoload not found!")
	#assert(Engine.has_singleton("DialogueManager"), "DialogueManager Autoload not found!")

	# 获取场景中的WaveManager节点
	_wave_manager = get_node_or_null("../WaveManager")
	assert(is_instance_valid(_wave_manager), "TutorialManager could not find sibling node WaveManager!")

	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	ConnectionManager.connection_made.connect(_on_connection_made)
	
	# 禁用WaveManager的自动开始功能，由教程控制
	_wave_manager.auto_start_on_ready = false

	# 等待场景过渡结束后再开始
	_wait_and_start()

func _wait_and_start():
	# 确保SceneManager是全局可访问的Autoload
	#assert(Engine.has_singleton("SceneManager"), "SceneManager Autoload not found!")
	
	# 等待，直到场景过渡动画结束
	while SceneManager.is_transitioning:
		await get_tree().process_frame
	
	# 额外等待一帧，确保输入系统完全准备就绪
	await get_tree().process_frame
		
	# 过渡已结束，现在可以安全地开始教学
	_start_initial_dialogue()

func _start_initial_dialogue():
	if initial_dialogue:
		DialogueManager.start_dialogue(initial_dialogue)

func _on_dialogue_finished(resource: DialogueResource):
	if resource == initial_dialogue:
		# 初始对话结束，进入等待玩家连接管道的状态
		print("TutorialManager: Initial dialogue finished. Waiting for blue connection.")
		_waiting_for_blue_connection = true
	elif resource == post_connect_dialogue:
		# 连接管道后的对话结束，现在可以触发敌人了
		print("TutorialManager: Post-connect dialogue finished. Triggering first wave.")
		_waiting_for_enemy_dialogue_end = false
		_wave_manager.trigger_next_wave()
		# 这里可以添加更多逻辑,比如进入下一个教学步骤

func _on_connection_made(pipe_type: int):
	if _waiting_for_blue_connection and pipe_type == Pipe.PipeType.SUPPLY: # SUPPLY_PIPE for blue (resource) pipes
		print("TutorialManager: Blue connection made! Waiting for build animation...")
		_waiting_for_blue_connection = false
		
		# 等待建造动画完成 (假设1.5秒足够)
		await get_tree().create_timer(2.5).timeout
		
		print("TutorialManager: Build animation finished. Starting post-connect dialogue.")
		if post_connect_dialogue:
			DialogueManager.start_dialogue(post_connect_dialogue)
			_waiting_for_enemy_dialogue_end = true
		else:
			printerr("TutorialManager: post_connect_dialogue is not assigned!")
			_wave_manager.trigger_next_wave() # 没有对话就直接出怪
