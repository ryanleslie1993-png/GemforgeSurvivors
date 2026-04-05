extends CanvasLayer

const CHARACTER_STATS_OVERLAY_SCENE := preload("res://scenes/ui/character_stats_overlay.tscn")
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")

var _character_stats_overlay: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PausePanel/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$PausePanel/VBoxContainer/CharacterStatsButton.pressed.connect(_on_character_stats_pressed)
	$PausePanel/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$PausePanel/VBoxContainer/ReturnButton.pressed.connect(_on_return_to_menu)


func _on_resume_pressed() -> void:
	visible = false
	get_tree().call_group("run_arena", "on_pause_resume_pressed")
	print("Pause overlay closed (resume)")


func _on_return_to_menu() -> void:
	# Forfeit run through arena end flow so end screen + meta rewards always happen.
	visible = false
	get_tree().call_group("run_arena", "end_run", false)
	print("Pause menu forfeit requested -> end_run(false)")


func _on_character_stats_pressed() -> void:
	if _character_stats_overlay == null:
		_character_stats_overlay = CHARACTER_STATS_OVERLAY_SCENE.instantiate() as CanvasLayer
		_character_stats_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_character_stats_overlay)
	visible = false
	if _character_stats_overlay.has_method("open_overlay"):
		_character_stats_overlay.call("open_overlay")
	print("Opened Character Stats overlay")


func _on_settings_pressed() -> void:
	var settings := SETTINGS_MENU_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child(settings)
	print("Opened Settings from pause menu")
