extends Node

## 导出一个字典，用于在编辑器中注册所有特效场景
## Key (String): 特效的唯一名称 (例如, "hit_effect", "bridge_explosion")
## Value (PackedScene): 特效的场景文件
@export var effect_scenes: Dictionary = {}

# 一个节点，用于容纳所有动态生成的特效，保持主场景树的整洁
var _vfx_container: Node

func _ready() -> void:
	# 最佳实践是拥有一个专门的节点来存放所有特效
	# 从现有代码来看，"Main/Foreground/Particles" 节点扮演了这个角色
	_vfx_container = get_tree().get_root().get_node_or_null("Main/Foreground/Particles")
	if not _vfx_container:
		push_error("VFXManager could not find the container node at '/root/Main/Foreground/Particles'. Please create it.")
		# 作为备用，直接添加到根节点，但这会很乱
		_vfx_container = get_tree().get_root()


## @brief 在指定位置播放一个已注册的视觉特效
## @param effect_name (String): 在 effect_scenes 字典中注册的特效名称
## @param position (Vector2): 特效播放的世界坐标
func play_effect(effect_name: String, position: Vector2) -> void:
	# 检查特效名称是否存在于字典中
	if not effect_scenes.has(effect_name):
		push_warning("VFXManager: Attempted to play an unregistered effect: '%s'" % effect_name)
		return
		
	# 获取预加载的场景
	var effect_scene: PackedScene = effect_scenes[effect_name]
	if not effect_scene:
		push_warning("VFXManager: Effect scene for '%s' is null." % effect_name)
		return
		
	# 实例化特效
	var effect_instance = effect_scene.instantiate()
	
	# 将特效添加到容器节点，并设置其位置
	_vfx_container.add_child(effect_instance)
	effect_instance.global_position = position
	
	# 检查实例是否有 'play' 方法（一个好的实践约定）
	if effect_instance.has_method("play"):
		effect_instance.play()
	# 如果是粒子效果，可以直接尝试设置 emitting
	elif effect_instance is GPUParticles2D or effect_instance is CPUParticles2D:
		effect_instance.emitting = true
	else:
		push_warning("VFXManager: Effect instance for '%s' has no 'play' method and is not a particle node." % effect_name)
