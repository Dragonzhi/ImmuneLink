# TutorialTrigger.gd
extends Node

## 一个简单的教学触发器，在延迟后开始一段对话。

@export var dialogue_resource: DialogueResource
@export var start_delay: float = 5.0

func _ready() -> void:
	var timer = get_tree().create_timer(start_delay)
	await timer.timeout
	
	if dialogue_resource:
		DialogueManager.start_dialogue(dialogue_resource)
	else:
		printerr("TutorialTrigger: No dialogue resource assigned!")
