extends Control
## View unlocked meta skills and placeholders for gear — opened from end-of-run or main menu.

const Catalog = preload("res://scripts/meta/meta_skill_tree_catalog.gd")


@onready var _class_label: Label = $RootVBox/ClassLabel
@onready var _list: RichTextLabel = $RootVBox/Scroll/RichList


func _ready() -> void:
	print("Inventory / Equipment screen loaded")
	$RootVBox/BackButton.pressed.connect(_on_back_pressed)
	_refresh()


func _refresh() -> void:
	Catalog.ensure_built()
	var class_id := ""
	if GameManager.current_class:
		class_id = str(GameManager.current_class.character_class_name)
	if class_id == "":
		class_id = "Guardian"
	_class_label.text = "Class: %s" % class_id
	var unlocked: Array[String] = MetaProgression.get_unlocked_list(class_id)
	var tree: Dictionary = Catalog.get_tree(class_id)
	var lines: PackedStringArray = []
	lines.append("[b]Unlocked skills[/b] (from meta tree)")
	for row in tree.get("nodes", []):
		var nid := str(row.get("id", ""))
		var kind := str(row.get("kind", ""))
		if kind != Catalog.KIND_CENTER and kind != Catalog.KIND_CORNER:
			continue
		if nid not in unlocked:
			continue
		var title := str(row.get("title", nid))
		lines.append("• %s" % title)
	if lines.size() <= 1:
		lines.append("• (none yet — unlock nodes in Meta Skill Tree)")
	lines.append("")
	lines.append("[b]Equipment slots[/b] (coming soon)")
	lines.append("Weapon, armor, and trinkets will appear here for swapping rolls between runs.")
	_list.text = "\n".join(lines)
	get_viewport().gui_release_focus()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
