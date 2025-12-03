extends Resource
class_name Upgrade

## 升级在UI中显示的名称
@export var upgrade_name: String = "New Upgrade"
## 升级的详细描述
@export var description: String = "Upgrade description."
## 升级所需的成本
@export var cost: int = 100
## 升级的图标
@export var icon: Texture2D

## 将此升级应用到目标节点上。这是一个“虚拟”方法，需要由子类来实现。
## @param target (Node): 通常是应用升级的对象，例如一个 'Bridge' 实例。
func apply(target: Node) -> void:
	# push_error() 会在Godot的调试器中打印一个错误，提醒我们子类没有正确实现这个方法。
	push_error("The 'apply' method is not implemented for this upgrade: %s" % resource_path)

## （可选）移除此升级效果的方法，为将来的“出售”或“撤销”功能做准备。
func unapply(target: Node) -> void:
	push_error("The 'unapply' method is not implemented for this upgrade: %s" % resource_path)
