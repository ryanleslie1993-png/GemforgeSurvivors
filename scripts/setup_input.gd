extends Node


func _ready():
	print("=== INPUT MAP CHECK ===")

	var actions: PackedStringArray = ["ui_left", "ui_right", "ui_up", "ui_down"]
	for action in actions:
		if not InputMap.has_action(action):
			print("Creating missing action: ", action)
			InputMap.add_action(action)
		else:
			print("Action exists: ", action)

	_ensure_default_bindings()

	print("Input Map check complete. Try WASD now.")


func _ensure_default_bindings() -> void:
	var bindings: Dictionary = {
		"ui_left": [KEY_A, KEY_LEFT],
		"ui_right": [KEY_D, KEY_RIGHT],
		"ui_up": [KEY_W, KEY_UP],
		"ui_down": [KEY_S, KEY_DOWN],
	}
	for action: String in bindings:
		for keycode: Key in bindings[action]:
			_add_key_if_missing(action, keycode)


func _add_key_if_missing(action: String, keycode: Key) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == keycode:
			return
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = keycode
	InputMap.action_add_event(action, key_ev)
	print("  Bound ", OS.get_keycode_string(keycode), " (", keycode, ") -> ", action)
