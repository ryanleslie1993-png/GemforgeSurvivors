extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PausePanel/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$PausePanel/VBoxContainer/ReturnButton.pressed.connect(_on_return_to_menu)


func _on_resume_pressed() -> void:
	visible = false
	get_tree().call_group("run_arena", "on_pause_resume_pressed")
	print("Pause overlay closed (resume)")


func _on_return_to_menu() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://main.tscn")
	print("Returned to main menu")
