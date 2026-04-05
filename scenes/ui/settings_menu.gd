extends CanvasLayer

@onready var _controls_label: Label = $CenterContainer/Panel/Margin/VBox/ControlsScroll/ControlsLabel
@onready var _reset_button: Button = $CenterContainer/Panel/Margin/VBox/ResetButton
@onready var _close_button: Button = $CenterContainer/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_button.pressed.connect(_on_reset_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_refresh_text()


func _refresh_text() -> void:
	if _controls_label:
		_controls_label.text = InputManager.get_controls_summary()


func _on_reset_pressed() -> void:
	InputManager.reset_to_defaults()
	_refresh_text()
	print("Settings: controls reset to defaults")


func _on_close_pressed() -> void:
	queue_free()
