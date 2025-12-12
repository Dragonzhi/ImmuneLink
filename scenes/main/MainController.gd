# MainController.gd
extends Node2D

@export var load_from_json: bool = false
@export var level_filename: String = "main.json" # 要加载的关卡文件名，例如 "level_01.json"

# LevelLoader 节点应作为此主节点的子节点。
@onready var level_loader: LevelLoader = $LevelLoader if has_node("LevelLoader") else null
@onready var wave_manager: WaveManager = $WaveManager if has_node("WaveManager") else null

func _ready():
	var config_data: Dictionary

	# --- 优先处理随机模式 ---
	if GameManager and GameManager.is_random_mode:
		print("MainController: 以随机模式启动。")
		GameManager.is_random_mode = false # 重置标志
		
		if not RandomLevelGenerator:
			printerr("MainController: 随机模式需要 RandomLevelGenerator 单例！")
			return
		if not level_loader:
			printerr("MainController: 随机模式需要 LevelLoader 节点！")
			return
		
		var random_data = RandomLevelGenerator.generate_random_level_data()
		config_data = level_loader.load_level_from_dictionary(random_data, self)

	# --- 处理预设或JSON模式 ---
	else:
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

		if load_from_json:
			# --- JSON加载模式 ---
			print("MainController: 以JSON模式启动。")
			
			var filename_only = json_path_to_load.get_file()
			if filename_only.is_empty():
				printerr("MainController: 未设置要加载的关卡JSON文件。")
				return

			if not level_loader:
				printerr("MainController: 未找到 LevelLoader 节点！无法从JSON加载。")
				return
			
			config_data = level_loader.load_level_from_json(filename_only, self)

		else:
			# --- 预设模式 ---
			print("MainController: 以预设模式启动。")
			if not wave_manager:
				printerr("MainController: 预设模式下未找到 WaveManager 节点！")
				return
			
			config_data = {
				"starting_resources": wave_manager.starting_resources,
				"game_time_limit": wave_manager.game_time_limit,
			}
			print("MainController: 成功从WaveManager读取预设配置。")

	# --- 通用设置流程 ---

	# 检查加载流程是否成功
	if config_data.is_empty():
		printerr("MainController: 加载关卡配置失败！无法继续。")
		# 可以在这里添加返回主菜单的逻辑
		return
	
	# 将当前场景的 WaveManager 实例传递给 GameManager
	if is_instance_valid(wave_manager):
		GameManager.wave_manager = wave_manager
	else:
		printerr("MainController: 未能获取到 WaveManager 实例！")

	# 统一调用 GameManager 进行设置
	if GameManager and GameManager.has_method("setup_level"):
		GameManager.setup_level(config_data)
	else:
		printerr("MainController: 无法调用 GameManager.setup_level()！")

	# 统一初始化 WaveManager
	if wave_manager:
		wave_manager.initialize_system()
	
	print("MainController: 关卡初始化流程完成。")
