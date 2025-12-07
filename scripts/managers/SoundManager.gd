# SoundManager.gd
extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_players_container: Node = $SFXPlayers

# 用于存储预加载的音效资源
var sfx_library: Dictionary = {}
var music_library: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer]
var _current_sfx_player_index: int = 0

func _ready() -> void:
	# 将所有 SFX 播放器收集到一个数组中以便快速访问
	_sfx_players.clear() 
	for child in sfx_players_container.get_children():
		var player = child as AudioStreamPlayer
		if player != null:
			_sfx_players.append(player)
	# --- 在这里预加载所有音效和音乐 ---
	# 示例:
	preload_sfx("ui_accept", "res://assets/audio/pepSound1.ogg")
	preload_sfx("ui_cancel", "res://assets/audio/pepSound2.ogg")
	preload_sfx("bridge_press", "res://assets/audio/phaserUp6.ogg")
	preload_sfx("ui_def", "res://assets/audio/tone1.ogg")
	preload_sfx("ui_error", "res://assets/audio/zap2.ogg")
	preload_sfx("ui_say", "res://assets/audio/confirmation_001.ogg")
	
	# preload_sfx("enemy_hit", "res://assets/sfx/enemy_hit.wav")
	 #preload_sfx("enemy_death", "res://assets/sfx/enemy_death.wav")
	# preload_sfx("tower_shoot", "res://assets/sfx/tower_shoot.wav")
	# preload_music("level_1_bgm", "res://assets/music/level_1.ogg")
	
	# 你可以稍后取消注释并填充这些
	pass

## 预加载一个音效并将其存储在库中
func preload_sfx(sound_name: String, path: String) -> void:
	if not sfx_library.has(sound_name):
		var stream = load(path)
		if stream:
			sfx_library[sound_name] = stream
		else:
			DebugManager.dprint("SoundManager Error: Failed to load SFX at path: %s" % path)

## 预加载一段音乐并将其存储在库中
func preload_music(music_name: String, path: String) -> void:
	if not music_library.has(music_name):
		var stream = load(path)
		if stream:
			music_library[music_name] = stream
		else:
			DebugManager.dprint("SoundManager Error: Failed to load music at path: %s" % path)

## 播放指定名称的音效
func play_sfx(sound_name: String) -> void:
	if not sfx_library.has(sound_name):
		DebugManager.dprint("SoundManager Error: SFX not found in library: %s" % sound_name)
		return

	# 从池中找到一个当前未播放的 AudioStreamPlayer
	var player = _get_available_sfx_player()
	if player:
		player.stream = sfx_library[sound_name]
		player.play()
	else:
		DebugManager.dprint("SoundManager Warning: No available SFX players to play: %s" % sound_name)

## 播放指定名称的音乐（会停止当前正在播放的音乐）
func play_music(music_name: String, loop: bool = true) -> void:
	if not music_library.has(music_name):
		DebugManager.dprint("SoundManager Error: Music not found in library: %s" % music_name)
		return
		
	music_player.stream = music_library[music_name]
	music_player.play()
	# Godot 的 AudioStreamPlayer 默认是循环播放的，但我们可以通过 loop 属性来控制
	# 注意：Godot 4 的 AudioStreamPlayer 没有直接的 loop 属性，循环是在导入时设置的。
	# 我们在这里假设导入设置是正确的。如果需要动态控制，需要使用 AudioStreamPlayback。

## 停止当前播放的音乐
func stop_music() -> void:
	music_player.stop()

## 停止所有音效
func stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()

## 设置音效音量
func set_sfx_volume_db(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), volume_db)

## 设置音乐音量
func set_music_volume_db(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), volume_db)

## 使用轮询方式获取一个可用的播放器
func _get_available_sfx_player() -> AudioStreamPlayer:
	for i in range(_sfx_players.size()):
		_current_sfx_player_index = (_current_sfx_player_index + 1) % _sfx_players.size()
		var player = _sfx_players[_current_sfx_player_index]
		if not player.is_playing():
			return player
	return null # 所有播放器都在忙
