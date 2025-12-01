extends Node2D

## 粒子数量
@export var particle_count: int = 150
## 粒子移动速度。较大的值意味着更快的移动。
@export var particle_speed: float = 20.0
## 粒子半径, x表示最小值，y表示最大值
@export var radius_range: Vector2 = Vector2(1.0, 3.0)

# 内部类：定义每个粒子的属性 (位置、速度、大小、颜色)
class Particle:
	var position: Vector2
	var velocity: Vector2 # This is now a normalized direction vector
	var radius: float
	var color: Color

var particles: Array[Particle] = []
var active_tween: Tween

# Store default values to return to
var _default_particle_count: int
var _default_particle_speed: float

func _ready():
	# Store initial values from the editor
	_default_particle_count = particle_count
	_default_particle_speed = particle_speed
	
	initialize_particles()
	
	# Connection logic is now removed from here.
	# WaveManager is now responsible for connecting to this node.


# (Re)Initializes all particles based on the current particle_count
func initialize_particles():
	_set_particle_count(particle_count)

func _create_single_particle() -> Particle:
	var screen_size = get_viewport_rect().size
	var p = Particle.new()
	p.position = Vector2(randf() * screen_size.x, randf() * screen_size.y)
	p.velocity = Vector2(randf() - 0.5, randf() - 0.5).normalized() # REFACTOR: Store direction only
	p.radius = randf_range(radius_range.x, radius_range.y)
	var alpha = randf() * 0.4 + 0.1
	var green_value = randf() * 0.3
	p.color = Color(1.0, green_value, 0.0, alpha) 
	return p

# NEW: Safely sets the number of particles, adding or removing as needed.
func _set_particle_count(new_count: int):
	var current_count = particles.size()
	new_count = int(new_count) # Ensure it's an integer for tweening
	
	if new_count > current_count:
		for i in range(new_count - current_count):
			particles.append(_create_single_particle())
	elif new_count < current_count:
		particles.resize(new_count)
	
	particle_count = new_count
		
# 游戏循环的更新逻辑
func _process(delta):
	var screen_size = get_viewport_rect().size
	
	for p in particles:
		# 1. 更新位置 - REFACTOR: Use particle_speed in real-time
		p.position += p.velocity * particle_speed * delta
		
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

# NEW: This function is called when the WaveManager starts a new wave.
func _on_wave_started(_wave_number: int):
	# Kill any previous animation to start the new one cleanly
	if active_tween and active_tween.is_running():
		active_tween.kill()

	active_tween = create_tween()
	
	var peak_speed = _default_particle_speed * 5.0
	#var peak_count = _default_particle_count * 4

	# --- Chain the animations together ---
	
	# 1. Ramp Up to peak values (in parallel)
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "particle_speed", peak_speed, 0.4).set_ease(Tween.EASE_OUT)
	#active_tween.tween_method(_set_particle_count, particle_count, peak_count, 0.4).set_ease(Tween.EASE_OUT)
	
	# 2. Switch to sequence mode to wait
	active_tween.set_parallel(false)
	active_tween.tween_interval(1.5) # Hold at peak for 1.5 seconds
	
	# 3. Ramp Down to default values (in parallel)
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "particle_speed", _default_particle_speed, 5.0).set_ease(Tween.EASE_IN)
	active_tween.tween_method(_set_particle_count, particle_count, _default_particle_count, 5.0).set_ease(Tween.EASE_IN)
