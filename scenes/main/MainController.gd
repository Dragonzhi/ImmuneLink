# MainController.gd
extends Node2D

@export var load_from_json: bool = false
@export_file("*.json") var level_json_path: String

# LevelLoader 节点应作为此主节点的子节点。
@onready var level_loader: LevelLoader = $LevelLoader if has_node("LevelLoader") else null
@onready var wave_manager: WaveManager = $WaveManager if has_node("WaveManager") else null

func _ready():
	if load_from_json:
		# --- 动态加载模式 ---
		if level_json_path.is_empty() or not ResourceLoader.exists(level_json_path):
			printerr("无效的JSON路径: '", level_json_path, "'")
			return

		if not level_loader:
			printerr("未找到 LevelLoader 节点！无法从JSON加载。")
			return
		
		# 调用加载器，并把当前场景根节点(self)传给它
		var success = level_loader.load_level_into_scene(level_json_path, self)

		if success:
			print("成功从JSON加载并配置关卡: ", level_json_path)
			# 在加载器成功后，重新初始化WaveManager以连接新信号
			if wave_manager:
				wave_manager.initialize_system()
		else:
			printerr("从JSON加载关卡失败: ", level_json_path)

	else:
		# --- 预设模式 ---
		# 游戏使用场景中已有的节点运行。
		if wave_manager:
			# Spawner 已在场景中，WaveManager的 @export 应该能获取到它们。
			wave_manager.initialize_system()
		print("以预设模式运行关卡。")
