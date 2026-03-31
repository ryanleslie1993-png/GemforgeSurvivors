extends CanvasLayer

signal replay_pressed
signal equipment_pressed
signal menu_pressed


func show_results(
	time_text: String,
	kills: int,
	dps_rows: Array,
	class_id: String,
	meta_level: int,
	meta_exp: int,
	meta_next: int,
	meta_gained: int,
	end_title: String
) -> void:
	visible = true
	$Panel/VBox/Title.text = end_title
	$Panel/VBox/TimeLabel.text = "Time Survived: %s" % time_text
	$Panel/VBox/KillsLabel.text = "Total Enemies Killed: %d" % kills
	var lines: PackedStringArray = []
	var rank: int = 1
	for row in dps_rows:
		var skill: String = str(row.get("skill", "Unknown"))
		var dmg: int = int(row.get("damage", 0))
		lines.append("%d. %s — %s dmg" % [rank, skill, _comma_int(dmg)])
		rank += 1
	$Panel/VBox/DpsLabel.text = "DPS Breakdown (Total Damage)\n%s" % ("\n".join(lines) if lines.size() > 0 else "- No recorded damage")

	var cls := class_id if class_id != "" else "(no class)"
	var gained_show: int = maxi(0, meta_gained)
	$Panel/VBox/MetaGainLabel.text = "Meta EXP gained this run: +%d  |  class: %s" % [gained_show, cls]
	$Panel/VBox/MetaClassTotalLabel.text = "%s — Meta level %d  |  %d / %d XP toward next level" % [cls, meta_level, meta_exp, maxi(1, meta_next)]
	$Panel/VBox/MetaXpBar.max_value = float(maxi(1, meta_next))
	$Panel/VBox/MetaXpBar.value = float(clampi(meta_exp, 0, meta_next))


func _ready() -> void:
	visible = false
	$Panel/VBox/ReplayButton.pressed.connect(_on_replay_button_pressed)
	$Panel/VBox/EquipmentButton.pressed.connect(_on_equipment_button_pressed)
	$Panel/VBox/MenuButton.pressed.connect(_on_menu_button_pressed)


func _on_replay_button_pressed() -> void:
	replay_pressed.emit()


func _on_equipment_button_pressed() -> void:
	equipment_pressed.emit()


func _on_menu_button_pressed() -> void:
	menu_pressed.emit()


func _comma_int(v: int) -> String:
	var s := str(maxi(0, v))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "," + s.substr(i - 3, 3) + out
		i -= 3
	return s.substr(0, i) + out
