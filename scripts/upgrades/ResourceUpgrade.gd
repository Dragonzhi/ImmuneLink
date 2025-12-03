extends Upgrade
class_name ResourceUpgrade

## 资源产出速率的乘数
## 例如: 1.5 表示将速率提升 50%
@export var rate_multiplier: float = 1.5

## 将“资源加速”升级应用到目标管道上
func apply(target: Node) -> void:
	var pipe = target as Pipe
	if not pipe:
		push_error("ResourceUpgrade can only be applied to a Pipe node.")
		return

	# 检查管道类型是否匹配（例如，只允许升级供给管道）
	if pipe.pipe_type != Pipe.PipeType.SUPPLY:
		print("此升级只能应用于'供给'类型的管道。")
		# 在实际游戏中，可以在显示UI前就过滤掉，这里作为双重保险
		return

	# 乘以速率乘数来提升资源产出
	pipe.resource_per_second *= rate_multiplier
	
	# 应用视觉效果（如果需要的话）
	if pipe.has_method("apply_visual_upgrade"):
		pipe.apply_visual_upgrade(self)
	
	print("资源加速升级已应用到管道 %s，新速率: %s" % [pipe.name, pipe.resource_per_second])
