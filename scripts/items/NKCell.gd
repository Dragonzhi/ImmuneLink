extends Node2D
class_name NKCell

signal collected(cell_node)

## 当NK细胞被拾取时调用
func collect():
	print("NK Cell collected at %s" % global_position)
	# 在这里可以添加被拾取时的视觉/声音效果，例如一个Tween动画
	
	# 发出信号，通知关心此事件的系统（例如GameManager）
	emit_signal("collected", self)
	
	# 从场景中移除自己
	queue_free()


func _ready() -> void:
	# 等待一帧，以确保所有节点（尤其是单例）都已准备就绪
	await get_tree().process_frame
	
	# 获取GridManager单例
	var grid_manager = get_node_or_null("/root/GridManager")
	if not grid_manager:
		printerr("NKCell: GridManager not found!")
		return
		
	# 计算自己所在的网格坐标
	var grid_pos = grid_manager.world_to_grid(global_position)
	
	# 将自己注册到GridManager中
	# 这会让其他系统知道这个格子被一个“物品”占据了
	grid_manager.set_grid_occupied(grid_pos, self)
	print("NK Cell registered at grid position: %s" % grid_pos)
