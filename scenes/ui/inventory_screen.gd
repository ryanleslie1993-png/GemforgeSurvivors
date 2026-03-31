extends Control
## Equipment & Gems screen with placeholder slots and responsive containers.

const Catalog = preload("res://scripts/meta/meta_skill_tree_catalog.gd")

const EQUIPPED_SLOTS := ["Weapon", "Armor", "Boots", "Accessory"]
const INVENTORY_SLOTS := 48

@onready var _class_label: Label = $ScreenMargin/RootVBox/HeaderHBox/ClassLabel
@onready var _equipped_grid: GridContainer = $ScreenMargin/RootVBox/MainHBox/EquippedPanel/EquippedMargin/EquippedVBox/EquippedGrid
@onready var _inventory_grid: GridContainer = $ScreenMargin/RootVBox/MainHBox/InventoryPanel/InventoryMargin/InventoryVBox/InventoryScroll/InventoryGrid


func _ready() -> void:
	print("Inventory / Equipment screen loaded")
	$ScreenMargin/RootVBox/BottomBar/BackButton.pressed.connect(_on_back_pressed)
	_refresh()


func _refresh() -> void:
	Catalog.ensure_built()
	var class_id: String = ""
	if GameManager.current_class:
		class_id = str(GameManager.current_class.character_class_name)
	if class_id == "":
		class_id = "Guardian"
	_class_label.text = "Class: %s" % class_id
	_populate_equipped_slots(class_id)
	_populate_inventory_slots(class_id)
	get_viewport().gui_release_focus()


func _populate_equipped_slots(class_id: String) -> void:
	for c in _equipped_grid.get_children():
		c.queue_free()
	for slot_name in EQUIPPED_SLOTS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 102)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		margin.add_child(row)
		var title := Label.new()
		title.text = "%s Slot" % slot_name
		title.add_theme_font_size_override("font_size", 18)
		row.add_child(title)
		var item_label := Label.new()
		item_label.text = "Equipped: (placeholder)"
		item_label.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
		row.add_child(item_label)
		var sockets := HBoxContainer.new()
		sockets.add_theme_constant_override("separation", 8)
		for i in range(3):
			var socket := PanelContainer.new()
			socket.custom_minimum_size = Vector2(26, 26)
			var gem_text := Label.new()
			gem_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gem_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			gem_text.text = "G%d" % (i + 1)
			socket.add_child(gem_text)
			sockets.add_child(socket)
		row.add_child(sockets)
		if slot_name == "Weapon":
			var unlocked: PackedStringArray = Catalog.unlocked_flag_summary_lines(class_id)
			var tip := Label.new()
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip.add_theme_color_override("font_color", Color(0.65, 0.82, 0.67))
			tip.text = "Meta unlocks: %s" % (", ".join(unlocked) if unlocked.size() > 0 else "none yet")
			row.add_child(tip)
		_equipped_grid.add_child(panel)


func _populate_inventory_slots(class_id: String) -> void:
	for c in _inventory_grid.get_children():
		c.queue_free()
	var unlocked: Array[String] = MetaProgression.get_unlocked_list(class_id)
	var tree: Dictionary = Catalog.get_tree(class_id)
	var major_titles: PackedStringArray = []
	for row in tree.get("nodes", []):
		var node_id: String = str(row.get("id", ""))
		var kind: String = str(row.get("kind", ""))
		if node_id in unlocked and (kind == Catalog.KIND_CENTER or kind == Catalog.KIND_CORNER):
			major_titles.append(str(row.get("title", node_id)))
	for i in range(INVENTORY_SLOTS):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(94, 94)
		var slot_label := Label.new()
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i < major_titles.size():
			slot_label.text = major_titles[i]
			slot_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
		else:
			slot_label.text = "Slot %02d" % (i + 1)
			slot_label.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
		slot.add_child(slot_label)
		_inventory_grid.add_child(slot)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
