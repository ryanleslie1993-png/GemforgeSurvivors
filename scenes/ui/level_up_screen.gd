extends CanvasLayer
## Centered level-up UI: 3–4 buff buttons with title, description, and rarity colors.

const Catalog = preload("res://scripts/level_up/level_up_buff_catalog.gd")

signal buff_selected(buff_id: String, buff_title: String, rarity: String)

var _buttons: Array[Button] = []
var _choices: Array[Dictionary] = []


func _gather_buttons() -> void:
	_buttons = [
		$CenterContainer/Panel/VBoxContainer/BuffButton1,
		$CenterContainer/Panel/VBoxContainer/BuffButton2,
		$CenterContainer/Panel/VBoxContainer/BuffButton3,
		$CenterContainer/Panel/VBoxContainer/BuffButton4,
	]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_gather_buttons()
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.pressed.connect(_on_buff_pressed.bind(i))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false


func show_level_up_choices() -> void:
	visible = true
	_choices = Catalog.roll_choices()
	for b in _buttons:
		b.disabled = false
	var n: int = _choices.size()
	for j in _buttons.size():
		if j < n:
			var row: Dictionary = _choices[j]
			var rarity: String = str(row.get("rarity", "common"))
			var title: String = str(row.get("title", ""))
			var desc: String = str(row.get("description", ""))
			var btn: Button = _buttons[j]
			btn.visible = true
			btn.text = "%s\n%s" % [title, desc]
			btn.add_theme_font_size_override("font_size", 15)
			_style_buff_button(btn, rarity)
		else:
			_buttons[j].visible = false
	print("Level up screen: offering ", n, " stat choices (no gem slots / skill gems — those come from Meta Tree).")


func _style_buff_button(btn: Button, rarity: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.14, 0.92)
	sb.border_color = Catalog.rarity_border_color(rarity)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb.duplicate())
	btn.add_theme_stylebox_override("pressed", sb.duplicate())
	btn.add_theme_stylebox_override("disabled", sb.duplicate())
	btn.add_theme_color_override("font_color", Catalog.rarity_font_color(rarity))
	btn.add_theme_color_override("font_hover_color", Catalog.rarity_font_color(rarity).lightened(0.08))
	btn.add_theme_color_override("font_pressed_color", Catalog.rarity_font_color(rarity).darkened(0.05))


func hide_level_up() -> void:
	visible = false


func _on_buff_pressed(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	for b in _buttons:
		b.disabled = true
	var row: Dictionary = _choices[index]
	var bid: String = str(row.get("id", ""))
	var title: String = str(row.get("title", ""))
	var rarity: String = str(row.get("rarity", "common"))
	buff_selected.emit(bid, title, rarity)
