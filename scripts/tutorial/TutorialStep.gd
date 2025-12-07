extends Resource
class_name TutorialStep

enum TriggerCondition {
	NONE,                   # 无特定触发，仅在延迟后继续
	DIALOGUE_FINISHED,      # 等待特定对话完成
	CONNECTION_MADE_TYPE,   # 等待特定类型的连接建立 (例如蓝色管道)
	TIMER_EXPIRED,          # 等待自定义计时器到期
	ENEMY_DEFEATED_COUNT,   # 等待一定数量的敌人被击败
	BRIDGE_BUILT,           # 等待桥梁建成
	CUSTOM_SIGNAL,          # 等待自定义信号 (更高级)
	INPUT_ACTION_PRESSED,   # 等待特定输入动作按下
	ACTION_TRIGGER_WAVE,    # 触发敌人波次
	UPGRADE_MENU_OPENED,    # 等待升级菜单打开
}

@export var step_name: String = "未命名步骤" # 用于编辑器显示，方便识别
@export var dialogue_resource: DialogueResource # 如果有对话，则引用此资源
@export var message_text: String = "" # 没有对话资源时，直接显示的消息 (用于屏幕中央提示等)
@export var delay_before_trigger: float = 0.0 # 在等待触发条件前，先等待指定时间
@export var trigger_condition: TriggerCondition = TriggerCondition.NONE
@export var trigger_data: String = "" # 触发条件所需的额外数据（例如，管道类型、敌人数量、信号名、输入动作名等）
@export var delay_after_completion: float = 0.0 # 步骤完成后，进入下一个步骤前的延迟

func _to_string() -> String:
	return "步骤: %s (对话: %s, 触发: %s)" % [step_name, dialogue_resource.resource_path.get_file() if dialogue_resource else "无", TriggerCondition.keys()[trigger_condition]]
