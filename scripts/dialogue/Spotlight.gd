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
		
	var rect: Rect2

	if node is Control:
		# 对于UI元素，get_global_rect() 是可靠的。
		rect = node.get_global_rect()
	elif node is Node2D:
		var sprite_found: Sprite2D = null
		for child in node.get_children():
			if child is Sprite2D:
				sprite_found = child
				break
		
		if sprite_found and sprite_found.texture:
			# Godot 4: Manually transform the corners to get the global bounding box
			var local_rect = sprite_found.get_rect()
			var global_transform = sprite_found.get_global_transform()
			
			var corners = [
				global_transform * local_rect.position,
				global_transform * (local_rect.position + Vector2(local_rect.size.x, 0)),
				global_transform * (local_rect.position + local_rect.size),
				global_transform * (local_rect.position + Vector2(0, local_rect.size.y))
			]
			
			rect = Rect2(corners[0], Vector2())
			for i in range(1, 4):
				rect = rect.expand(corners[i])
		else:
			# Fallback to default size if no Sprite2D is found or has no texture
			var node_size = Vector2(32, 32) # 使用一个默认大小
			rect = Rect2(node.global_position - node_size / 2.0, node_size)
	else:
		# 如果是无法处理的类型，则隐藏聚光灯
		printerr("Spotlight: Cannot determine rect for node of type %s" % node.get_class())
		hide_spotlight()
		return

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
