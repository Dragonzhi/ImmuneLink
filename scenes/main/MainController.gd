# MainController.gd
extends Node2D

@export var load_from_json: bool = false
@export_file("*.json") var level_json_path: String

# LevelLoader 节点应作为此主节点的子节点。
@onready var level_loader: LevelLoader = $LevelLoader if has_node("LevelLoader") else null
@onready var wave_manager: WaveManager = $WaveManager if has_node("WaveManager") else null

func _ready():
	# 1. 准备一个空的配置字典
	var config_data: Dictionary

	if load_from_json:
		# --- JSON加载模式 ---
		print("MainController: 以JSON模式启动。")
		if level_json_path.is_empty() or not ResourceLoader.exists(level_json_path):
			printerr("MainController: 无效的JSON路径: '%s'" % level_json_path)
			return

		if not level_loader:
			printerr("MainController: 未找到 LevelLoader 节点！无法从JSON加载。")
			return
		
		# 调用加载器加载场景节点，并获取关卡配置数据
		config_data = level_loader.load_level_from_json(level_json_path, self)

		if config_data.is_empty():
			printerr("MainController: 从JSON加载关卡失败: %s" % level_json_path)
			return
		print("MainController: 成功从JSON加载场景节点。")

	else:
		# --- 预设模式 ---
		print("MainController: 以预设模式启动。")
		if not wave_manager:
			printerr("MainController: 预设模式下未找到 WaveManager 节点！")
			return
		
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
