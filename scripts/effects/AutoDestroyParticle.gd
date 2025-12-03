extends GPUParticles2D

# 通用脚本：用于附加在设置为 one-shot 的粒子特效上，使其播放完毕后自动销毁。

func _ready() -> void:
	# 确保在编辑器中将此粒子系统设置为 one-shot
	if not one_shot:
		push_warning("粒子特效 '%s' 没有在检查器中设置为 one_shot (单次播放)，可能无法正确自动销毁。" % name)
	
	# 当粒子系统播放完成时，连接 finished 信号到 queue_free 方法
	self.finished.connect(queue_free)


# 提供一个标准的 play 方法，用于从代码中（如VFXManager）启动特效
func play() -> void:
	emitting = true
