extends Node
## Hard-codes core gameplay actions so WASD, skills, and basic attack work even if project Input Map is empty or corrupted.

#region Action names (used by player and UI)
const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_MOVE_UP := "move_up"
const ACTION_MOVE_DOWN := "move_down"
const ACTION_BASIC_ATTACK := "basic_attack"
const SKILL_SLOT_ACTIONS: Array[String] = [
	"skill_slot_1",
	"skill_slot_2",
	"skill_slot_3",
	"skill_slot_4",
	"skill_slot_5",
	"skill_slot_6",
	"skill_slot_7",
]
#endregion


func _ready() -> void:
	reset_to_defaults()
	print("InputManager: Hard-coded controls loaded")


func reset_to_defaults() -> void:
	# Movement (gameplay)
	_replace_keys(ACTION_MOVE_LEFT, [KEY_A, KEY_LEFT])
	_replace_keys(ACTION_MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_replace_keys(ACTION_MOVE_UP, [KEY_W, KEY_UP])
	_replace_keys(ACTION_MOVE_DOWN, [KEY_S, KEY_DOWN])
	# Mirror to ui_* for compatibility
	_replace_keys("ui_left", [KEY_A, KEY_LEFT])
	_replace_keys("ui_right", [KEY_D, KEY_RIGHT])
	_replace_keys("ui_up", [KEY_W, KEY_UP])
	_replace_keys("ui_down", [KEY_S, KEY_DOWN])

	_replace_mouse(ACTION_BASIC_ATTACK, MOUSE_BUTTON_LEFT)

	_replace_keys(SKILL_SLOT_ACTIONS[0], [KEY_Q])
	_replace_keys(SKILL_SLOT_ACTIONS[1], [KEY_E])
	_replace_keys(SKILL_SLOT_ACTIONS[2], [KEY_R])
	_replace_keys(SKILL_SLOT_ACTIONS[3], [KEY_F])
	_replace_keys(SKILL_SLOT_ACTIONS[4], [KEY_SPACE])
	_replace_keys(SKILL_SLOT_ACTIONS[5], [KEY_SHIFT])
	_replace_mouse(SKILL_SLOT_ACTIONS[6], MOUSE_BUTTON_RIGHT)


func get_controls_summary() -> String:
	var lines: PackedStringArray = []
	lines.append("MOVEMENT (also bound to ui_left / ui_right / ui_up / ui_down)")
	lines.append("  Left:  %s" % _human_action(ACTION_MOVE_LEFT))
	lines.append("  Right: %s" % _human_action(ACTION_MOVE_RIGHT))
	lines.append("  Up:    %s" % _human_action(ACTION_MOVE_UP))
	lines.append("  Down:  %s" % _human_action(ACTION_MOVE_DOWN))
	lines.append("")
	lines.append("BASIC ATTACK")
	lines.append("  %s" % _human_action(ACTION_BASIC_ATTACK))
	lines.append("")
	lines.append("SKILL SLOTS")
	var labels := ["Q", "E", "R", "F", "Space", "Shift", "Right Click"]
	for i in range(SKILL_SLOT_ACTIONS.size()):
		lines.append("  Slot %d (%s): %s" % [i + 1, labels[i], _human_action(SKILL_SLOT_ACTIONS[i])])
	return "\n".join(lines)


func _human_action(action: String) -> String:
	if not InputMap.has_action(action):
		return "(not registered)"
	var parts: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			parts.append((ev as InputEventKey).as_text().trim_prefix("(Physical) "))
		elif ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					parts.append("Left mouse")
				MOUSE_BUTTON_RIGHT:
					parts.append("Right mouse")
				_:
					parts.append("Mouse %d" % mb.button_index)
	return ", ".join(parts) if parts.size() else "(no bindings)"


func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _replace_keys(action_name: String, keycodes: Array) -> void:
	_ensure_action(action_name)
	InputMap.action_erase_events(action_name)
	for k in keycodes:
		var key_ev := InputEventKey.new()
		key_ev.physical_keycode = k as Key
		InputMap.action_add_event(action_name, key_ev)


func _replace_mouse(action_name: String, button_index: MouseButton) -> void:
	_ensure_action(action_name)
	InputMap.action_erase_events(action_name)
	var mb := InputEventMouseButton.new()
	mb.button_index = button_index
	InputMap.action_add_event(action_name, mb)
