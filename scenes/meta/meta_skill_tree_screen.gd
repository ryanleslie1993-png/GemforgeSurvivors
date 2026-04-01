extends Control

const Catalog = preload("res://scripts/meta/meta_skill_tree_catalog.gd")

@onready var _class_option: OptionButton = $RootVBox/TopBar/ClassOption
@onready var _class_name_label: Label = $RootVBox/TopBar/ClassNameLabel
@onready var _points_label: Label = $RootVBox/TopBar/PointsLabel
@onready var _meta_xp_line: Label = $RootVBox/TopBar/MetaXpLine
@onready var _tree_scroll: ScrollContainer = $RootVBox/MainSplit/RightPanel/TreeScroll
@onready var _graph: Control = $RootVBox/MainSplit/RightPanel/TreeScroll/MetaSkillTreeGraph
@onready var _name_value: Label = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll/NodeDetailsVBox/NodeNameValue
@onready var _bonus_value: Label = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll/NodeDetailsVBox/BonusValue
@onready var _desc_value: RichTextLabel = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll/NodeDetailsVBox/DescriptionValue
@onready var _cost_value: Label = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll/NodeDetailsVBox/CostValue
@onready var _prereq_value: Label = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll/NodeDetailsVBox/PrereqValue
@onready var _status_value: Label = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll/NodeDetailsVBox/StatusValue
@onready var _stats_rich: RichTextLabel = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/StatsSection/StatsScroll/StatsRich
@onready var _node_details_scroll: ScrollContainer = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/NodeDetailsScroll
@onready var _stats_scroll: ScrollContainer = $RootVBox/MainSplit/LeftPanel/MarginContainer/DetailsStatsSplit/StatsSection/StatsScroll
@onready var _unlock_btn: Button = $RootVBox/BottomBar/UnlockButton
@onready var _reset_btn: Button = $RootVBox/BottomBar/ResetButton
var _selected_node_id: String = ""


func _ready() -> void:
	print("Meta Skill Tree screen loaded")
	Catalog.ensure_built()
	$RootVBox/TopBar/BackButton.pressed.connect(_on_back_pressed)
	_class_option.item_selected.connect(_on_class_selected)
	_unlock_btn.pressed.connect(_on_unlock_pressed)
	_reset_btn.pressed.connect(_on_reset_pressed)
	if _graph.has_signal("node_pressed"):
		_graph.node_pressed.connect(_on_graph_node_pressed)
	_populate_classes()
	var idx := 0
	if GameManager.current_class and GameManager.current_class.character_class_name != "":
		for i in range(_class_option.item_count):
			if _class_option.get_item_text(i) == GameManager.current_class.character_class_name:
				idx = i
				break
	if _class_option.item_count > 0:
		_class_option.select(idx)
	_refresh_for_class(_class_id_from_index(idx))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _populate_classes() -> void:
	_class_option.clear()
	var ids := Catalog.get_all_class_ids()
	for i in range(ids.size()):
		_class_option.add_item(String(ids[i]))


func _class_id_from_index(idx: int) -> String:
	if idx < 0 or idx >= _class_option.item_count:
		return ""
	return _class_option.get_item_text(idx)


func _on_class_selected(index: int) -> void:
	_refresh_for_class(_class_id_from_index(index))


func _refresh_for_class(class_id: String) -> void:
	_update_points_label(class_id)
	_class_name_label.text = "Class: %s" % class_id
	if _graph.has_method("set_tree_class"):
		_graph.set_tree_class(class_id)
	_name_value.text = "-"
	_bonus_value.text = "-"
	_desc_value.text = "Hover or click a node to inspect details."
	_cost_value.text = "-"
	_prereq_value.text = "-"
	_status_value.text = "Locked"
	_unlock_btn.disabled = true
	_unlock_btn.set_meta("pending_node", "")
	_selected_node_id = ""
	_update_character_stats_panel(class_id)
	call_deferred("_center_on_start_node", class_id)


func _center_on_start_node(class_id: String) -> void:
	if class_id == "" or _tree_scroll == null or _graph == null:
		return
	var start_node_id: String = Catalog.get_starting_node_id(class_id)
	if start_node_id == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _graph.has_method("get_node_center"):
		return
	var center_local: Vector2 = _graph.call("get_node_center", start_node_id)
	if center_local.x < 0.0 or center_local.y < 0.0:
		return
	var viewport_size: Vector2 = _tree_scroll.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target_x: float = center_local.x - viewport_size.x * 0.5
	var target_y: float = center_local.y - viewport_size.y * 0.5
	var hbar: HScrollBar = _tree_scroll.get_h_scroll_bar()
	var vbar: VScrollBar = _tree_scroll.get_v_scroll_bar()
	var max_x: float = hbar.max_value if hbar else 0.0
	var max_y: float = vbar.max_value if vbar else 0.0
	_tree_scroll.scroll_horizontal = int(clampf(target_x, 0.0, max_x))
	_tree_scroll.scroll_vertical = int(clampf(target_y, 0.0, max_y))
	print("Skill tree centered on starting node: ", start_node_id)


func _update_character_stats_panel(class_id: String) -> void:
	if class_id == "" or _stats_rich == null:
		return
	var agg: Dictionary = MetaProgression.aggregate_bonuses(class_id)
	var stat_lines: PackedStringArray = Catalog.format_accumulated_stats_lines(agg)
	var flag_lines: PackedStringArray = Catalog.unlocked_flag_summary_lines(class_id)
	var blocks: PackedStringArray = []
	if stat_lines.is_empty() and flag_lines.is_empty():
		blocks.append("[i]No stat bonuses yet. Unlock passives to fill this list.[/i]")
	else:
		if not stat_lines.is_empty():
			blocks.append("[b]Attribute bonuses[/b]")
			for line in stat_lines:
				blocks.append("• %s" % line)
		if not flag_lines.is_empty():
			if not stat_lines.is_empty():
				blocks.append("")
			blocks.append("[b]Major skill unlocks[/b]")
			for line in flag_lines:
				blocks.append("• %s" % line)
	_stats_rich.text = "\n".join(blocks)
	call_deferred("_scroll_stats_to_top")


func _update_points_label(class_id: String) -> void:
	var pts: int = MetaProgression.get_points(class_id)
	_points_label.text = "Meta Skill Points: %d" % pts
	if _meta_xp_line:
		if class_id == "":
			_meta_xp_line.text = "Meta XP: —"
		else:
			var d: Dictionary = MetaProgression.get_meta_level_data_for_class(class_id)
			_meta_xp_line.text = "Meta XP — Lv %d — %d / %d toward next — Points: %d" % [int(d["level"]), int(d["exp"]), int(d["next"]), pts]


func _on_graph_node_pressed(node_id: String) -> void:
	var class_id: String = _class_id_from_index(_class_option.selected)
	if class_id == "":
		return
	var row: Dictionary = Catalog.find_node(class_id, node_id)
	if row.is_empty():
		return
	var desc: String = str(row.get("description", ""))
	var cost: int = int(row.get("cost", 0))
	var unlocked: bool = MetaProgression.is_unlocked(class_id, node_id)
	var can: bool = MetaProgression.can_unlock(class_id, node_id)
	_name_value.text = str(row.get("title", node_id))
	_bonus_value.text = Catalog.format_bonus_for_ui(row.get("bonus", {}))
	_desc_value.text = desc if desc != "" else "—"
	_cost_value.text = str(cost)
	_prereq_value.text = _build_prereq_text(class_id, row)
	_status_value.text = "Unlocked" if unlocked else ("Can Unlock" if can else "Locked")
	_selected_node_id = node_id
	_unlock_btn.set_meta("pending_node", node_id)
	_unlock_btn.disabled = unlocked or not can
	call_deferred("_scroll_node_details_to_top")


func _on_unlock_pressed() -> void:
	unlock_selected_node()


func unlock_selected_node() -> void:
	var current_class: String = _class_id_from_index(_class_option.selected)
	var selected_node_id: String = _selected_node_id
	if selected_node_id == "":
		selected_node_id = str(_unlock_btn.get_meta("pending_node", ""))
	print("Attempting to unlock node: ", selected_node_id, " for class: ", current_class)
	if current_class == "" or selected_node_id == "":
		print("Unlock aborted: no class/node selected.")
		return
	var row: Dictionary = Catalog.find_node(current_class, selected_node_id)
	if row.is_empty():
		print("Unlock aborted: node not found in catalog.")
		return
	var node_cost: int = int(row.get("cost", 0))
	var points_before: int = MetaProgression.get_points(current_class)
	if points_before < node_cost:
		print("Unlock failed: not enough meta points (have ", points_before, ", need ", node_cost, ").")
		_on_graph_node_pressed(selected_node_id)
		return
	if not MetaProgression.can_unlock(current_class, selected_node_id):
		print("Unlock failed: prerequisites not met or node already unlocked.")
		_on_graph_node_pressed(selected_node_id)
		return
	if not MetaProgression.unlock_node(current_class, selected_node_id):
		print("Unlock failed unexpectedly in MetaProgression.unlock_node.")
		_on_graph_node_pressed(selected_node_id)
		return
	MetaProgression.save_progress()
	print("Unlock successful! Points remaining: ", MetaProgression.get_points(current_class))
	_update_points_label(current_class)
	_update_character_stats_panel(current_class)
	if _graph.has_method("refresh_unlock_state"):
		_graph.refresh_unlock_state()
	if _graph and _graph is CanvasItem:
		(_graph as CanvasItem).queue_redraw()
	_on_graph_node_pressed(selected_node_id)


func _on_reset_pressed() -> void:
	var class_id: String = _class_id_from_index(_class_option.selected)
	if class_id == "":
		return
	MetaProgression.reset_class_tree(class_id)
	_update_points_label(class_id)
	_update_character_stats_panel(class_id)
	if _graph.has_method("refresh_unlock_state"):
		_graph.refresh_unlock_state()
	if _selected_node_id != "":
		_on_graph_node_pressed(_selected_node_id)


func _build_prereq_text(class_id: String, row: Dictionary) -> String:
	var req_names: PackedStringArray = []
	for rid in row.get("prereqs", []):
		var found := Catalog.find_node(class_id, str(rid))
		if found.is_empty():
			continue
		req_names.append(str(found.get("title", str(rid))))
	return "None" if req_names.is_empty() else ", ".join(req_names)


func _scroll_stats_to_top() -> void:
	if _stats_scroll:
		_stats_scroll.scroll_vertical = 0


func _scroll_node_details_to_top() -> void:
	if _node_details_scroll:
		_node_details_scroll.scroll_vertical = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready() and _class_option:
		var idx: int = _class_option.selected
		if idx >= 0 and _class_option.item_count > 0:
			call_deferred("_refresh_for_class", _class_id_from_index(idx))
