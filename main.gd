extends Control


func _ready() -> void:
	print("Main Menu loaded")
	$MenuButtons/CharacterSelectButton.pressed.connect(_on_character_select_pressed)
	$MenuButtons/PlayButton.pressed.connect(_on_play_pressed)
	$MenuButtons/BlacksmithButton.pressed.connect(_on_blacksmith_pressed)
	$MenuButtons/GemsmithButton.pressed.connect(_on_gemsmith_pressed)
	$MenuButtons/InventoryButton.pressed.connect(_on_inventory_pressed)
	$MenuButtons/MetaSkillTreeButton.pressed.connect(_on_meta_skill_tree_pressed)


func _on_character_select_pressed() -> void:
	print("Opening Character Select...")
	get_tree().change_scene_to_file("res://scenes/character_select/character_select.tscn")


func _on_play_pressed() -> void:
	print("Starting run (Guardian default)...")
	var class_data := ClassData.new()
	class_data.character_class_name = "Guardian"
	GameManager.current_class = class_data
	get_tree().change_scene_to_file("res://scenes/run_arena/run_arena.tscn")


func _on_blacksmith_pressed() -> void:
	print("Opening Equipment & Gems (Blacksmith)")
	get_tree().change_scene_to_file("res://scenes/ui/inventory_screen.tscn")


func _on_gemsmith_pressed() -> void:
	print("Opening Equipment & Gems (Gemsmith)")
	get_tree().change_scene_to_file("res://scenes/ui/inventory_screen.tscn")


func _on_inventory_pressed() -> void:
	print("Opening Equipment & Gems...")
	get_tree().change_scene_to_file("res://scenes/ui/inventory_screen.tscn")


func _on_meta_skill_tree_pressed() -> void:
	print("Opening Meta Skill Tree...")
	get_tree().change_scene_to_file("res://scenes/meta/meta_skill_tree_screen.tscn")
