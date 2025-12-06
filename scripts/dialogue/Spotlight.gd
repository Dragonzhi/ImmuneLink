# Spotlight.gd
class_name Spotlight
extends CanvasLayer

## 聚光灯效果的控制器。
## 通过操作Shader的uniform参数来高亮显示屏幕的特定区域。

@onready var overlay: ColorRect = $Overlay

# --- 公共API ---

## 让聚光灯聚焦于一个场景节点
func focus_on_node(node: CanvasItem):
	if not is_instance_valid(node):
		hide_spotlight()
		return
		
	# 获取节点的矩形区域
	var rect = node.get_rect() # 对于Sprite2D等, 这通常是其纹理的大小
	if node is Control:
		rect = node.get_global_rect()
	else:
		# 对于Node2D, 我们需要手动计算其在屏幕上的矩形
		# 这里做一个简化，使用节点的global_position和固定大小
		# 一个更完整的实现需要考虑节点的实际边界和缩放
		var node_size = Vector2(64, 64) # 假设一个默认大小
		rect = Rect2(node.global_position - node_size / 2.0, node_size)

	focus_on_rect(rect)

## 让聚光灯聚焦于一个屏幕矩形区域
func focus_on_rect(screen_rect: Rect2):
	if not overlay.material is ShaderMaterial:
		printerr("Spotlight: Overlay material is not a ShaderMaterial!")
		return

	visible = true
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# 将屏幕坐标和大小转换为UV坐标 (0-1)
	var center_uv = screen_rect.get_center() / viewport_size
	var size_uv = screen_rect.size / viewport_size
	
	# 更新Shader的uniform参数
	overlay.material.set_shader_parameter("hole_center", center_uv)
	overlay.material.set_shader_parameter("hole_size", size_uv)

## 隐藏聚光灯
func hide_spotlight():
	visible = false

# --- 私有方法 ---

func _ready():
	# 默认隐藏
	hide_spotlight()
