# TutorialManager.gd
#class_name TutorialManager # Autoload 脚本不需要 class_name
extends Node

## 教程管理器，用于引导玩家完成教学关卡步骤。
## 现在通过 TutorialSequence 资源驱动，实现灵活配置。

@export var dialogue_box_node_path: NodePath # DialogueBox 节点的路径，例如 "../../GameUI/DialogueBox"

var _wave_manager: WaveManager
var _current_tutorial_sequence: TutorialSequence = null # 新增：存储当前教程序列
var _current_step_index: int = -1
var _current_step_timer: Timer = null # 用于 TIMER_EXPIRED 触发条件

# 信号，用于通知外部教程已完成
signal tutorial_completed

func _ready() -> void:
	# 禁用WaveManager的自动开始功能，由教程控制
	#if _wave_manager:
		#_wave_manager.auto_start_on_ready = false

	# DebugManager 注册
	DebugManager.register_category("TutorialManager", false)

	# 等待场景过渡结束后。现在start_tutorial_with_sequence由GameManager调用
	_wait_and_start_tutorial()

func _wait_and_start_tutorial():
	# 等待，直到场景过渡动画结束
	while SceneManager.is_transitioning:
		await get_tree().process_frame
	
	# 额外等待一帧，确保输入系统完全准备就绪
	await get_tree().process_frame
		
	# 过渡已结束，现在等待GameManager调用 start_tutorial_with_sequence

## 启动教程，并传入要运行的教程序列
func start_tutorial_with_sequence(sequence: TutorialSequence):
	# 获取场景中的WaveManager节点
	# 注意：如果TutorialManager是Autoload，则WaveManager也应是Autoload或由GameManager管理
	_wave_manager = get_node_or_null("/root/Main/WaveManager") # 假设WaveManager是Autoload或Main的直接子节点
	if not _wave_manager:
		printerr("TutorialManager: 无法找到WaveManager!")
		# 如果是Autoload，这里可能会失败，直到WaveManager的_ready执行

	_current_tutorial_sequence = sequence # 保存传入的序列

	if not _current_tutorial_sequence:
		printerr("TutorialManager: 没有提供教程序列！")
		return

	_current_step_index = -1 # 重置步骤索引
	DebugManager.dprint("TutorialManager", "教程开始: '%s'" % _current_tutorial_sequence.sequence_name)
	_go_to_next_step()

## 推进到下一个教程步骤
func _go_to_next_step():
	_cleanup_current_step() # 清理上一步的监听器和计时器
	
	if not _current_tutorial_sequence: return # 如果没有序列，则不进行

	_current_step_index += 1
	if _current_step_index >= _current_tutorial_sequence.steps.size():
		DebugManager.dprint("TutorialManager", "所有教程步骤已完成！")
		emit_signal("tutorial_completed")
		return

	var current_step = _current_tutorial_sequence.steps[_current_step_index]
	DebugManager.dprint("TutorialManager", "执行步骤: %s" % current_step.step_name)
	
	_execute_step(current_step)

## 执行单个教程步骤的核心逻辑
func _execute_step(step: TutorialStep):
	# 1. 处理延迟 (delay_before_trigger)
	if step.delay_before_trigger > 0:
		DebugManager.dprint("TutorialManager", "等待 %s 秒..." % step.delay_before_trigger)
		await get_tree().create_timer(step.delay_before_trigger).timeout
	
	# 2. 显示对话或消息
	if step.dialogue_resource:
		DialogueManager.start_dialogue(step.dialogue_resource)
	elif not step.message_text.is_empty():
		# 如果没有 DialogueResource 但有 message_text，可以在这里显示一个临时的UI提示
		# For now, just print to console
		print("教程提示: %s" % step.message_text) # 这里的print仍然使用，因为不是DebugManager的常规输出

	# 3. 等待触发条件
	match step.trigger_condition:
		TutorialStep.TriggerCondition.NONE:
			# 如果没有触发条件，仅等待对话完成或直接进入下一个延迟
			if step.dialogue_resource:
				# 连接信号，等待对话完成
				DialogueManager.dialogue_finished.connect(_on_current_dialogue_finished)
			else:
				_handle_step_completion(step) # 没有对话且没有触发条件，直接完成步骤
		
		TutorialStep.TriggerCondition.DIALOGUE_FINISHED:
			# 连接信号，等待对话完成
			if step.dialogue_resource:
				DialogueManager.dialogue_finished.connect(_on_current_dialogue_finished)
			else:
				printerr("TutorialManager: 步骤 '%s' 配置了 DIALOGUE_FINISHED 但没有 dialogue_resource!" % step.step_name)
				_handle_step_completion(step) # 错误，直接完成
		
		TutorialStep.TriggerCondition.CONNECTION_MADE_TYPE:
			# 等待特定类型的管道连接
			if ConnectionManager:
				ConnectionManager.connection_made.connect(_on_connection_made_type)
				DebugManager.dprint("TutorialManager", "等待连接类型: %s" % step.trigger_data)
			else:
				printerr("TutorialManager: ConnectionManager not found for CONNECTION_MADE_TYPE!")
				_handle_step_completion(step) # 错误，直接完成
		
		TutorialStep.TriggerCondition.TIMER_EXPIRED:
			# 等待自定义计时器到期
			if not step.trigger_data.is_empty():
				_current_step_timer = Timer.new()
				_current_step_timer.wait_time = float(step.trigger_data)
				_current_step_timer.one_shot = true
				add_child(_current_step_timer)
				_current_step_timer.timeout.connect(func(): _on_custom_timer_timeout(step))
				_current_step_timer.start()
				DebugManager.dprint("TutorialManager", "等待计时器 (%s秒) 到期..." % step.trigger_data)
			else:
				printerr("TutorialManager: TIMER_EXPIRED 条件未设置 trigger_data (秒数)!")
				_handle_step_completion(step) # 错误，直接完成
		
		TutorialStep.TriggerCondition.ENEMY_DEFEATED_COUNT:
			# 等待一定数量敌人被击败
			# 需要 GameManger 提供相应信号，这里只是示例
			# GameManager.enemy_defeated.connect(_on_enemy_defeated)
			printerr("TutorialManager: ENEMY_DEFEATED_COUNT 尚未实现！")
			_handle_step_completion(step) # 暂未实现，直接完成
		
		TutorialStep.TriggerCondition.BRIDGE_BUILT:
			# 等待桥梁建成
			# BridgeBuilder.bridge_built.connect(_on_bridge_built)
			printerr("TutorialManager: BRIDGE_BUILT 尚未实现！")
			_handle_step_completion(step) # 暂未实现，直接完成
			
		TutorialStep.TriggerCondition.INPUT_ACTION_PRESSED:
			# 等待特定输入动作按下
			# 确保Input是单例，并在_input中监听
			set_process_input(true) # 启用_input处理
			DebugManager.dprint("TutorialManager", "等待输入动作: %s" % step.trigger_data)
			# Input 监听将在 _input 函数中进行处理
		
		TutorialStep.TriggerCondition.ACTION_TRIGGER_WAVE:
			# 立即触发敌人波次
			if _wave_manager:
				_wave_manager.trigger_next_wave()
				DebugManager.dprint("TutorialManager", "已触发敌人波次。")
			else:
				printerr("TutorialManager: WaveManager 未找到，无法触发波次！")
			_handle_step_completion(step)
		
		_:
			printerr("TutorialManager: 未知触发条件：%s" % step.trigger_condition)
			_handle_step_completion(step) # 错误，直接完成

func _input(event: InputEvent) -> void:
	# 只有当教程正在进行中，并且当前步骤需要监听输入时才处理
	if _current_step_index < 0 || _current_step_index >= _current_tutorial_sequence.steps.size():
		return 

	var current_step = _current_tutorial_sequence.steps[_current_step_index]
	if current_step.trigger_condition == TutorialStep.TriggerCondition.INPUT_ACTION_PRESSED:
		if event.is_action_pressed(current_step.trigger_data):
			DebugManager.dprint("TutorialManager", "输入动作 '%s' 已按下。" % current_step.trigger_data)
			set_process_input(false) # 禁用 _input 处理
			_handle_step_completion(current_step)
			get_viewport().set_input_as_handled() # 消耗事件

## 步骤完成后的处理（包括 delay_after_completion）
func _handle_step_completion(step: TutorialStep):
	_cleanup_current_step() # 确保所有信号都已断开
	
	if step.delay_after_completion > 0:
		DebugManager.dprint("TutorialManager", "步骤完成，等待 %s 秒进入下一步..." % step.delay_after_completion)
		await get_tree().create_timer(step.delay_after_completion).timeout
	
	_go_to_next_step()

## 清理当前步骤的监听器和计时器
func _cleanup_current_step():
	# Disconnect all signals related to TutorialManager
	if DialogueManager.dialogue_finished.is_connected(_on_current_dialogue_finished):
		DialogueManager.dialogue_finished.disconnect(_on_current_dialogue_finished)
	if ConnectionManager.connection_made.is_connected(_on_connection_made_type):
		ConnectionManager.connection_made.disconnect(_on_connection_made_type)
	
	# Disconnect all other potential connections here (e.g., from GameManager, BridgeBuilder)
	# if GameManager.enemy_defeated.is_connected(_on_enemy_defeated):
	#    GameManager.enemy_defeated.disconnect(_on_enemy_defeated)
	# if BridgeBuilder.bridge_built.is_connected(_on_bridge_built):
	#    BridgeBuilder.bridge_built.disconnect(_on_bridge_built)
	
	if _current_step_timer and is_instance_valid(_current_step_timer):
		_current_step_timer.stop()
		_current_step_timer.queue_free()
		_current_step_timer = null
	
	set_process_input(false) # 确保_input处理被禁用，除非必要


# --- 信号处理函数 ---

func _on_current_dialogue_finished(resource: DialogueResource):
	# 确保是当前步骤的对话
	# 注意: _current_tutorial_sequence 可能会在 start_tutorial_with_sequence 未被调用时为 null
	if not _current_tutorial_sequence or _current_step_index < 0 || _current_step_index >= _current_tutorial_sequence.steps.size():
		DebugManager.dprint("TutorialManager", "对话完成信号，但教程状态异常。")
		return

	var current_step = _current_tutorial_sequence.steps[_current_step_index]
	if current_step.dialogue_resource == resource:
		DebugManager.dprint("TutorialManager", "对话 '%s' 已完成。" % resource.resource_path.get_file())
		_handle_step_completion(current_step)

func _on_connection_made_type(pipe_type: int):
	# 注意: _current_tutorial_sequence 可能会在 start_tutorial_with_sequence 未被调用时为 null
	if not _current_tutorial_sequence or _current_step_index < 0 || _current_step_index >= _current_tutorial_sequence.steps.size():
		DebugManager.dprint("TutorialManager", "连接建立信号，但教程状态异常。")
		return

	var current_step = _current_tutorial_sequence.steps[_current_step_index]
	if current_step.trigger_condition == TutorialStep.TriggerCondition.CONNECTION_MADE_TYPE:
		# 假设 trigger_data 存储的是 Pipe.PipeType 的整数值或字符串名称
		# 需要将 pipe_type (int) 转换为 PipeType 的字符串名称进行比较
		var expected_pipe_type_str = current_step.trigger_data
		var actual_pipe_type_str = Pipe.PipeType.keys()[pipe_type]

		if expected_pipe_type_str == actual_pipe_type_str:
			DebugManager.dprint("TutorialManager", "检测到期望的连接类型: %s" % actual_pipe_type_str)
			_handle_step_completion(current_step)
		else:
			DebugManager.dprint("TutorialManager", "连接类型不匹配。期望: %s, 实际: %s" % [expected_pipe_type_str, actual_pipe_type_str])

func _on_custom_timer_timeout(step: TutorialStep):
	# 确保是当前步骤的计时器
	# 注意: _current_tutorial_sequence 可能会在 start_tutorial_with_sequence 未被调用时为 null
	if not _current_tutorial_sequence or _current_step_index < 0 || _current_step_index >= _current_tutorial_sequence.steps.size():
		DebugManager.dprint("TutorialManager", "计时器超时，但教程状态异常。")
		return
	
	DebugManager.dprint("TutorialManager", "计时器条件 '%s' 已满足。" % step.step_name)
	_handle_step_completion(step)
