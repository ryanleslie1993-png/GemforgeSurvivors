extends Control
## Draws prerequisite lines and hosts one Button per meta tree node.

signal node_pressed(node_id: String)

const Catalog = preload("res://scripts/meta/meta_skill_tree_catalog.gd")

var _class_id: String = ""
var _node_centers: Dictionary = {} # String -> Vector2 (local center for lines)
var _node_rows: Dictionary = {} # String -> Dictionary
const CANVAS_SIZE := Vector2(3400, 2450)
const CANVAS_MARGIN := 198.0

const PASSIVE_SIZE := Vector2(24, 24)
const CENTER_SIZE := Vector2(188, 68)
const MAJOR_SIZE := Vector2(176, 62)


func set_tree_class(class_id: String) -> void:
	if _class_id == class_id:
		_refresh_all_buttons()
		return
	_class_id = class_id
	for c in get_children():
		c.queue_free()
	_node_centers.clear()
	_node_rows.clear()
	if class_id == "":
		queue_redraw()
		return
	var tree: Dictionary = Catalog.get_tree(class_id)
	custom_minimum_size = CANVAS_SIZE
	var usable := CANVAS_SIZE - Vector2(CANVAS_MARGIN * 2.0, CANVAS_MARGIN * 2.0)
	for row in tree.get("nodes", []):
		var nid: String = str(row.get("id", ""))
		var pos_n: Vector2 = row.get("pos", Vector2(0.5, 0.5))
		var center := Vector2(CANVAS_MARGIN, CANVAS_MARGIN) + pos_n * usable
		_node_centers[nid] = center
		_node_rows[nid] = row
		var btn := Button.new()
		var cost: int = int(row.get("cost", 0))
		var title: String = str(row.get("title", nid))
		var kind: String = str(row.get("kind", "passive"))
		var desc: String = str(row.get("description", ""))
		var bonus_line: String = Catalog.format_bonus_for_ui(row.get("bonus", {}))
		btn.tooltip_text = _build_tooltip(title, kind, bonus_line, desc, cost)
		if kind == Catalog.KIND_PASSIVE:
			btn.text = ""
			btn.custom_minimum_size = PASSIVE_SIZE
			var s_passive := StyleBoxFlat.new()
			s_passive.bg_color = Color(0.5, 0.52, 0.58, 1)
			s_passive.border_width_left = 2
			s_passive.border_width_top = 2
			s_passive.border_width_right = 2
			s_passive.border_width_bottom = 2
			s_passive.border_color = Color(0.12, 0.13, 0.16, 1)
			var r := int(mini(PASSIVE_SIZE.x, PASSIVE_SIZE.y) / 2)
			s_passive.corner_radius_top_left = r
			s_passive.corner_radius_top_right = r
			s_passive.corner_radius_bottom_left = r
			s_passive.corner_radius_bottom_right = r
			btn.add_theme_stylebox_override("normal", s_passive)
			var hov := s_passive.duplicate()
			hov.bg_color = Color(0.58, 0.6, 0.66, 1)
			btn.add_theme_stylebox_override("hover", hov)
			var prs := s_passive.duplicate()
			prs.bg_color = Color(0.44, 0.46, 0.52, 1)
			btn.add_theme_stylebox_override("pressed", prs)
			btn.add_theme_stylebox_override("disabled", s_passive.duplicate())
		elif kind == Catalog.KIND_CENTER:
			btn.text = title if cost <= 0 else "%s\n%d pt" % [title, cost]
			btn.custom_minimum_size = CENTER_SIZE
			btn.add_theme_font_size_override("font_size", 14)
			_apply_major_style(btn, Color(0.22, 0.36, 0.52), Color(0.32, 0.5, 0.72))
		else:
			btn.text = title if cost <= 0 else "%s\n%d pt" % [title, cost]
			btn.custom_minimum_size = MAJOR_SIZE
			btn.add_theme_font_size_override("font_size", 13)
			_apply_major_style(btn, Color(0.28, 0.22, 0.45), Color(0.42, 0.34, 0.62))
		btn.position = center - btn.custom_minimum_size * 0.5
		btn.set_meta("node_id", nid)
		btn.pressed.connect(func(): node_pressed.emit(nid))
		add_child(btn)
	_refresh_all_buttons()
	queue_redraw()


func _apply_major_style(btn: Button, bg: Color, border_c: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.border_color = border_c
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left = 8
	s.content_margin_top = 6
	s.content_margin_right = 8
	s.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", h)
	var p := s.duplicate()
	p.bg_color = bg.darkened(0.06)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", s.duplicate())


func _build_tooltip(title: String, kind: String, bonus_line: String, desc: String, cost: int) -> String:
	var parts: PackedStringArray = [title]
	if bonus_line != "—":
		parts.append(bonus_line)
	if desc != "":
		parts.append(desc)
	if cost > 0:
		parts.append("Cost: %d meta point(s)" % cost)
	return "\n".join(parts)


func refresh_unlock_state() -> void:
	_refresh_all_buttons()
	queue_redraw()


func _refresh_all_buttons() -> void:
	if _class_id == "":
		return
	for btn in get_children():
		if not btn is Button:
			continue
		var nid: String = str(btn.get_meta("node_id", ""))
		if nid == "":
			continue
		var unlocked: bool = MetaProgression.is_unlocked(_class_id, nid)
		var can: bool = MetaProgression.can_unlock(_class_id, nid)
		var row: Dictionary = _node_rows.get(nid, {})
		var kind: String = str(row.get("kind", Catalog.KIND_PASSIVE))
		if unlocked:
			btn.modulate = Color(0.75, 1.0, 0.82) if kind != Catalog.KIND_PASSIVE else Color(0.45, 0.95, 0.66)
			btn.disabled = false
		elif can:
			btn.modulate = Color(1.0, 0.92, 0.65) if kind != Catalog.KIND_PASSIVE else Color(0.98, 0.84, 0.45)
			btn.disabled = false
		else:
			btn.modulate = Color(0.55, 0.55, 0.58) if kind != Catalog.KIND_PASSIVE else Color(0.46, 0.47, 0.5)
			btn.disabled = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _class_id != "" and get_child_count() > 0:
		_relayout_buttons()


func _ready() -> void:
	resized.connect(_on_graph_resized)


func _on_graph_resized() -> void:
	if _class_id != "" and get_child_count() > 0:
		_relayout_buttons()


func _relayout_buttons() -> void:
	var usable := CANVAS_SIZE - Vector2(CANVAS_MARGIN * 2.0, CANVAS_MARGIN * 2.0)
	var tree: Dictionary = Catalog.get_tree(_class_id)
	for row in tree.get("nodes", []):
		var nid: String = str(row.get("id", ""))
		var pos_n: Vector2 = row.get("pos", Vector2(0.5, 0.5))
		var center := Vector2(CANVAS_MARGIN, CANVAS_MARGIN) + pos_n * usable
		_node_centers[nid] = center
	for btn in get_children():
		if not btn is Button:
			continue
		var nid2: String = str(btn.get_meta("node_id", ""))
		if _node_centers.has(nid2):
			var c2: Vector2 = _node_centers[nid2]
			btn.position = c2 - btn.custom_minimum_size * 0.5
	queue_redraw()


func _draw() -> void:
	if _class_id == "":
		return
	var tree: Dictionary = Catalog.get_tree(_class_id)
	for row in tree.get("nodes", []):
		var to_id: String = str(row.get("id", ""))
		if not _node_centers.has(to_id):
			continue
		var p1: Vector2 = _node_centers[to_id]
		for pr in row.get("prereqs", []):
			var pid: String = str(pr)
			if not _node_centers.has(pid):
				continue
			var p0: Vector2 = _node_centers[pid]
			var col := Color(0.34, 0.36, 0.4, 0.75)
			if MetaProgression.is_unlocked(_class_id, to_id) and MetaProgression.is_unlocked(_class_id, pid):
				col = Color(0.22, 0.62, 0.44, 0.88)
			draw_line(p0, p1, col, 2.5, true)
