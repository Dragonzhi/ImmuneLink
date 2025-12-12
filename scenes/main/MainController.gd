# MainController.gd
extends Node2D

@export var load_from_json: bool = false
@export var level_filename: String = "main.json" # 要加载的关卡文件名，例如 "level_01.json"

# LevelLoader 节点应作为此主节点的子节点。
@onready var level_loader: LevelLoader = $LevelLoader if has_node("LevelLoader") else null
@onready var wave_manager: WaveManager = $WaveManager if has_node("WaveManager") else null

func _ready():
	# 决定要加载哪个JSON文件
	var json_path_to_load: String = ""
	if GameManager and not GameManager.custom_level_json_path.is_empty():
		# 优先使用来自LevelSelect界面的选择
		print("MainController: 检测到来自GameManager的自定义关卡路径。")
		json_path_to_load = GameManager.custom_level_json_path
		GameManager.custom_level_json_path = "" # 用完后立即清空，防止下次误用
		load_from_json = true # 强制进入JSON加载模式
	else:
		# 回退到编辑器中设置的默认值
		json_path_to_load = level_filename

	# 1. 准备一个空的配置字典
	var config_data: Dictionary

	if load_from_json:
		# --- JSON加载模式 ---
		print("MainController: 以JSON模式启动。")
		if json_path_to_load.is_empty():
			printerr("MainController: 未设置要加载的关卡JSON文件。")
			return

		if not level_loader:
			printerr("MainController: 未找到 LevelLoader 节点！无法从JSON加载。")
			return
		
		# 调用加载器加载场景节点，并获取关卡配置数据
		config_data = level_loader.load_level_from_json(json_path_to_load, self)

		if config_data.is_empty():
			printerr("MainController: 从JSON加载关卡失败: %s" % json_path_to_load)
			return
		print("MainController: 成功从JSON加载场景节点。")
		
		# 将当前场景的 WaveManager 实例传递给 GameManager
		if is_instance_valid(wave_manager):
			GameManager.wave_manager = wave_manager
		else:
			printerr("MainController: JSON模式下未能获取到 WaveManager 实例！")

	else:
		# --- 预设模式 ---
		print("MainController: 以预设模式启动。")
		if not wave_manager:
			printerr("MainController: 预设模式下未找到 WaveManager 节点！")
			return
		
		# 将当前场景的 WaveManager 实例传递给 GameManager
		GameManager.wave_manager = wave_manager

		# 从WaveManager直接读取配置，构建配置字典
		config_data = {
			"starting_resources": wave_manager.starting_resources,
			"game_time_limit": wave_manager.game_time_limit,
		}
		print("MainController: 成功从WaveManager读取预设配置。")

	# 2. 统一调用 GameManager 进行设置
	if GameManager and GameManager.has_method("setup_level"):
		GameManager.setup_level(config_data)
	else:
		printerr("MainController: 无法调用 GameManager.setup_level()！")

	# 3. 统一初始化 WaveManager
	if wave_manager:
		wave_manager.initialize_system()
	
	print("MainController: 关卡初始化流程完成。")
