extends Control

const Catalog = preload("res://scripts/meta/meta_skill_tree_catalog.gd")

## Matches `simple_player.gd` `_apply_unique_class_passive` fantasy (short UI blurbs).
const CLASS_PASSIVE_BLURBS: Dictionary = {
	"Paladin": "Radiance — 5% of all healing becomes AoE holy damage (scales with meta holy damage).",
	"Guardian": "Bulwark — below 50% HP, take 12% less damage from hits.",
	"Berserker": "Blood Fury — below 50% HP, deal 15% more damage.",
	"Elementalist": "Wildfire — burn damage over time is 12% stronger.",
	"Assassin": "Predator's Eye — +10% critical strike chance.",
	"Ranger": "Strider — +12% movement speed.",
	"Druid": "Verdant Heart — +0.35% max HP regeneration per second.",
	"Necromancer": "Grave Momentum — +10% projectile speed.",
}

const BASE_HP := 120
const BASE_SPEED := 450.0
const BUTTON_MIN := Vector2(260, 54)

var selected_class: String = ""
var _meta_bars: Dictionary = {} # class_id -> ProgressBar
var _meta_account_label: Label

@onready var _class_list_scroll: ScrollContainer = $ScreenMargin/MainVBox/MainHBox/ClassListScroll
@onready var _class_list: VBoxContainer = $ScreenMargin/MainVBox/MainHBox/ClassListScroll/ClassList
@onready var _details_scroll: ScrollContainer = $ScreenMargin/MainVBox/MainHBox/DetailsScroll
@onready var _details_panel: PanelContainer = $ScreenMargin/MainVBox/MainHBox/DetailsScroll/DetailsPanel
@onready var _details_column: VBoxContainer = $ScreenMargin/MainVBox/MainHBox/DetailsScroll/DetailsPanel/DetailsMargin/DetailsColumn


func _ready() -> void:
	print("Character Select loaded")
	Catalog.ensure_built()

	_meta_account_label = Label.new()
	_meta_account_label.name = "MetaAccountSummary"
	_meta_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta_account_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta_account_label.add_theme_font_size_override("font_size", 14)
	_meta_account_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	_class_list.add_child(_meta_account_label)
	_class_list.move_child(_meta_account_label, 1)

	_rebuild_class_list_with_meta_bars()
	_refresh_meta_account_ui()

	for row in _class_list.get_children():
		if row is VBoxContainer and row.get_child_count() > 0:
			var btn := row.get_child(0) as Button
			if btn:
				btn.pressed.connect(_on_class_button_pressed.bind(btn.text))

	$ScreenMargin/MainVBox/BottomBar/BackButton.pressed.connect(_on_back_pressed)
	$ScreenMargin/MainVBox/BottomBar/PlayButton.pressed.connect(_on_play_pressed)
	$ScreenMargin/MainVBox/BottomBar/ViewTreeButton.pressed.connect(_on_view_tree_pressed)
	$ScreenMargin/MainVBox/BottomBar/EquipmentButton.pressed.connect(_on_equipment_pressed)

	_details_scroll.resized.connect(_on_details_scroll_resized)
	_class_list_scroll.resized.connect(_on_class_list_scroll_resized)
	call_deferred("_on_details_scroll_resized")
	call_deferred("_on_class_list_scroll_resized")

	var first := _first_class_id()
	if first != "":
		_on_class_button_pressed(first)


func _on_details_scroll_resized() -> void:
	var w := int(_details_scroll.size.x)
	if w > 8:
		_details_panel.custom_minimum_size.x = maxi(380, w - 16)


func _on_class_list_scroll_resized() -> void:
	var w := int(_class_list_scroll.size.x)
	if w > 8:
		_class_list.custom_minimum_size.x = maxi(300, w - 8)


func _rebuild_class_list_with_meta_bars() -> void:
	var buttons: Array[Button] = []
	for c in _class_list.get_children():
		if c is Button:
			buttons.append(c as Button)
	for btn in buttons:
		_class_list.remove_child(btn)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_class_list.add_child(row)
		btn.custom_minimum_size = BUTTON_MIN
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		row.add_child(bar)
		_meta_bars[btn.text] = bar


func _first_class_id() -> String:
	for row in _class_list.get_children():
		if row is VBoxContainer and row.get_child_count() > 0 and row.get_child(0) is Button:
			return (row.get_child(0) as Button).text
	return ""


func _refresh_meta_account_ui() -> void:
	if _meta_account_label:
		_meta_account_label.text = "Per-class meta XP — each bar is for that class only."
	for class_id in _meta_bars.keys():
		var d: Dictionary = MetaProgression.get_meta_level_data_for_class(class_id)
		var bar: ProgressBar = _meta_bars[class_id]
		var clvl: int = int(d.get("level", 1))
		var cexp: int = int(d.get("exp", 0))
		var cnxt: int = maxi(1, int(d.get("next", 1)))
		bar.max_value = float(cnxt)
		bar.value = float(clampi(cexp, 0, cnxt))
		bar.tooltip_text = "%s — Meta Lv %d — %d / %d XP toward next" % [class_id, clvl, cexp, cnxt]


func _on_class_button_pressed(class_name_str: String) -> void:
	selected_class = class_name_str
	print("Selected: ", class_name_str)
	_refresh_meta_account_ui()

	_details_column.get_node("NameLabel").text = class_name_str
	var agg: Dictionary = MetaProgression.aggregate_bonuses(class_name_str)
	var hp_approx: int = BASE_HP + int(agg.get("max_health_flat", 0))
	_details_column.get_node("HealthLabel").text = "Health (run start, +meta): %d" % hp_approx
	_details_column.get_node("SpeedLabel").text = "Base move speed: %d (class passives + meta apply in run)" % int(BASE_SPEED)

	var passive: String = str(CLASS_PASSIVE_BLURBS.get(class_name_str, "Unique passive for this class (see in-run tooltips)."))
	_details_column.get_node("PassiveLabel").text = "Unique passive: %s" % passive

	_details_column.get_node("MetaTreeInfoLabel").text = _build_meta_skill_summary(class_name_str)
	_update_character_stats_display(class_name_str)

	for row in _class_list.get_children():
		if row is VBoxContainer and row.get_child_count() > 0 and row.get_child(0) is Button:
			var btn := row.get_child(0) as Button
			btn.modulate = Color.WHITE if btn.text != class_name_str else Color(1.0, 0.92, 0.35)

	call_deferred("_on_details_scroll_resized")
	call_deferred("_scroll_details_to_top")


func _scroll_details_to_top() -> void:
	_details_scroll.scroll_vertical = 0


func _update_character_stats_display(class_id: String) -> void:
	var rich: RichTextLabel = _details_column.get_node("CharacterStatsRich") as RichTextLabel
	if rich == null:
		return
	if class_id == "":
		rich.text = "[i]Select a class to see stats.[/i]"
		return
	var stat_agg: Dictionary = MetaProgression.aggregate_bonuses(class_id)
	var stat_lines: PackedStringArray = Catalog.format_accumulated_stats_lines(stat_agg)
	var flag_lines: PackedStringArray = Catalog.unlocked_flag_summary_lines(class_id)
	var blocks: PackedStringArray = []
	if stat_lines.is_empty() and flag_lines.is_empty():
		blocks.append("[i]No stat bonuses from meta yet for this class. Unlock passives in View Skill Tree.[/i]")
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
	rich.text = "\n".join(blocks)


func _build_meta_skill_summary(class_id: String) -> String:
	var lines: PackedStringArray = []
	var unlocked: Array[String] = MetaProgression.get_unlocked_list(class_id)
	var start_id: String = Catalog.get_starting_node_id(class_id)
	if start_id != "":
		var cn: Dictionary = Catalog.find_node(class_id, start_id)
		var t: String = str(cn.get("title", "Starting skill"))
		lines.append("Starting skill: %s" % t)
	else:
		lines.append("Starting skill: (unknown)")

	var majors: PackedStringArray = []
	for nid in unlocked:
		var row: Dictionary = Catalog.find_node(class_id, nid)
		if row.is_empty():
			continue
		if str(row.get("kind", "")) == Catalog.KIND_CORNER:
			majors.append(str(row.get("title", nid)))

	if majors.is_empty():
		lines.append("Major corner unlocks: none yet — use View Skill Tree.")
	else:
		lines.append("Unlocked major nodes:")
		for m in majors:
			lines.append("  • %s" % m)

	var flags: PackedStringArray = Catalog.unlocked_flag_summary_lines(class_id)
	if not flags.is_empty():
		lines.append("Skill flags from passives:")
		for fl in flags:
			lines.append("  • %s" % fl)

	return "\n".join(lines)


func _on_back_pressed() -> void:
	print("Back to Main Menu")
	get_tree().change_scene_to_file("res://main.tscn")


func _on_play_pressed() -> void:
	if selected_class == "":
		print("Please select a class first")
		return

	print("Starting run with ", selected_class)
	var class_data := ClassData.new()
	class_data.character_class_name = selected_class
	GameManager.current_class = class_data
	GameManager.mark_next_run_as_new()
	get_tree().change_scene_to_file("res://scenes/run_arena/run_arena.tscn")


func _on_view_tree_pressed() -> void:
	var target_class := selected_class
	if target_class == "":
		target_class = "Guardian"
	var class_data := ClassData.new()
	class_data.character_class_name = target_class
	GameManager.current_class = class_data
	print("Opening Meta Skill Tree for ", target_class)
	get_tree().change_scene_to_file("res://scenes/meta/meta_skill_tree_screen.tscn")


func _on_equipment_pressed() -> void:
	var target_class := selected_class
	if target_class == "":
		target_class = "Guardian"
	var class_data := ClassData.new()
	class_data.character_class_name = target_class
	GameManager.current_class = class_data
	print("Opening Equipment & Gems for ", target_class)
	get_tree().change_scene_to_file("res://scenes/ui/inventory_screen.tscn")
