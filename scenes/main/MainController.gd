# MainController.gd
extends Node2D

@export var load_from_json: bool = false
@export_file("*.json") var level_json_path: String

# The LevelLoader node is expected to be a child of this Main node.
@onready var level_loader: LevelLoader = $LevelLoader if has_node("LevelLoader") else null
@onready var wave_manager: WaveManager = $WaveManager if has_node("WaveManager") else null

func _ready():
    if load_from_json:
        # --- Dynamic Loading Mode ---
        if level_json_path.is_empty() or not ResourceLoader.exists(level_json_path):
            printerr("JSON path is not valid: '", level_json_path, "'")
            return

        if not level_loader:
            printerr("LevelLoader node not found! Cannot load from JSON.")
            return

        # Clear preset elements from the scene
        _clear_preset_elements()

        # Load level data
        var loaded_data = level_loader.load_level(level_json_path)
        if loaded_data:
            # Add loaded nodes to this scene
            var level_root = loaded_data.level_root
            for n in level_root.get_children():
                level_root.remove_child(n)
                add_child(n)
            level_root.queue_free()

            # Configure WaveManager with loaded data
            if wave_manager:
                wave_manager.waves = loaded_data.waves
                var spawners_group = get_tree().get_nodes_in_group("spawners")
                wave_manager.spawners = spawners_group
                wave_manager.initialize_system()

            # Configure GameManager with starting resources (example)
            var game_manager = find_child("GameManager", true, false)
            if game_manager and game_manager.has_method("set_resources"):
                 game_manager.set_resources(loaded_data.starting_resources)
            
            print("Successfully loaded level from JSON: ", level_json_path)
    else:
        # --- Preset Mode ---
        # The game runs with nodes already in the scene.
        if wave_manager:
            # Spawners are already in the scene, WaveManager's @export should pick them up.
            wave_manager.initialize_system()
        print("Running level in preset mode.")

func _clear_preset_elements():
    # This function removes pre-placed "pipes" and "spawners" from the scene
    # to make way for the dynamically loaded ones.
    for group_name in ["pipes", "spawners"]:
        for node in get_tree().get_nodes_in_group(group_name):
            if node.owner == self: # Check if the node is owned by this scene
                 node.queue_free()
