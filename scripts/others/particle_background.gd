extends Node2D

# 导出变量，可以在编辑器中调整粒子数量
@export var particle_count: int = 150
# 粒子移动速度。较大的值意味着更快的移动。
@export var particle_speed: float = 1.0

# 内部类：定义每个粒子的属性 (位置、速度、大小、颜色)
class Particle:
	var position: Vector2
	var velocity: Vector2
	var radius: float
	var color: Color

var particles: Array[Particle] = []

func _ready():
	# 确保视图尺寸可用，等待一帧
	await get_tree().process_frame
	initialize_particles()
	# 设置节点始终在背景绘制（可选，但推荐）
	# self.z_index = -1 

# 初始化所有粒子
func initialize_particles():
	var screen_size = get_viewport_rect().size
	particles.clear()
	
	for i in range(particle_count):
		var p = Particle.new()
		
		# 1. 随机初始位置
		p.position = Vector2(randf() * screen_size.x, randf() * screen_size.y)
		
		# 2. 随机速度 (-0.5到0.5), 乘以 speed 变量控制整体速度
		p.velocity = Vector2( (randf() - 0.5) * particle_speed, (randf() - 0.5) * particle_speed)
		
		# 3. 随机半径 (1到3)
		p.radius = randf() * 2.0 + 1.0
		
		# 4. 颜色：半透明的红色/橙色，模拟炎症或能量光晕
		var alpha = randf() * 0.4 + 0.1 # 0.1到0.5的透明度
		var green_value = randf() * 0.3 # 限制绿色分量，保持红色调
		# Color(Red, Green, Blue, Alpha)
		p.color = Color(1.0, green_value, 0.0, alpha) 
		
		particles.append(p)
		
# 游戏循环的更新逻辑
func _process(delta):
	var screen_size = get_viewport_rect().size
	
	for p in particles:
		# 1. 更新位置
		# 乘以 delta 确保帧率独立性，乘以 100.0 让速度更明显
		p.position += p.velocity * delta * 100.0 
		
		# 2. 屏幕包裹 (Toroidal wrap) - 粒子超出边界后从对面出现
		
		# X轴包裹
		if p.position.x < 0:
			p.position.x += screen_size.x
		elif p.position.x > screen_size.x:
			p.position.x -= screen_size.x
			
		# Y轴包裹
		if p.position.y < 0:
			p.position.y += screen_size.y
		elif p.position.y > screen_size.y:
			p.position.y -= screen_size.y
	
	# 强制重绘，触发 _draw() 函数
	queue_redraw()

# 渲染逻辑 (每当 queue_redraw() 被调用时执行)
func _draw():
	# 在这里绘制所有粒子
	for p in particles:
		# draw_circle(中心位置, 半径, 颜色)
		draw_circle(p.position, p.radius, p.color)
