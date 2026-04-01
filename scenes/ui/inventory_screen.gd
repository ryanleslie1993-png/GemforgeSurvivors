extends Control

const DISPLAY_SLOT_TO_RUNTIME_SLOT := {
	"WeaponSlot": "weapon",
	"HelmSlot": "armor",
	"OffHandSlot": "accessory",
	"AmuletSlot": "accessory",
	"GloveSlot": "armor",
	"ChestSlot": "armor",
	"PantsSlot": "armor",
	"BootSlot": "boots",
	"Ring1Slot": "accessory",
	"Ring2Slot": "accessory",
}

const DISPLAY_SLOT_LABEL := {
	"WeaponSlot": "Weapon",
	"HelmSlot": "Helm",
	"OffHandSlot": "Off Hand",
	"AmuletSlot": "Amulet",
	"GloveSlot": "Glove",
	"ChestSlot": "Chest",
	"PantsSlot": "Pants",
	"BootSlot": "Boot",
	"Ring1Slot": "Ring 1",
	"Ring2Slot": "Ring 2",
}

var _current_class_id: String = "Guardian"
var _inventory_grid: GridContainer

var _selected_inventory_index: int = -1
var _selected_equipped_slot_type: String = ""
var _selected_item: Dictionary = {}

@onready var _title_label: Label = $MainMargin/RootVBox/TitleLabel
@onready var _blacksmith_button: Button = $MainMargin/RootVBox/BottomBar/BlacksmithButton
@onready var _gemsmith_button: Button = $MainMargin/RootVBox/BottomBar/GemsmithButton
@onready var _main_menu_button: Button = $MainMargin/RootVBox/BottomBar/MainMenuButton

@onready var _inspector_title: Label = $MainMargin/RootVBox/TopArea/TopRightSpacer/InspectorMargin/InspectorVBox/InspectorTitle
@onready var _inspector_details: RichTextLabel = $MainMargin/RootVBox/TopArea/TopRightSpacer/InspectorMargin/InspectorVBox/InspectorDetails
@onready var _equip_button: Button = $MainMargin/RootVBox/TopArea/TopRightSpacer/InspectorMargin/InspectorVBox/InspectorButtons/EquipButton
@onready var _unequip_button: Button = $MainMargin/RootVBox/TopArea/TopRightSpacer/InspectorMargin/InspectorVBox/InspectorButtons/UnequipButton
@onready var _socket_button: Button = $MainMargin/RootVBox/TopArea/TopRightSpacer/InspectorMargin/InspectorVBox/InspectorButtons/SocketGemButton


func _ready() -> void:
	print("Inventory screen _ready() - Root children: ", get_children())
	_current_class_id = GameManager.get_current_class_key()
	_title_label.text = "Equipment & Gems - %s" % _current_class_id

	_inventory_grid = _resolve_inventory_grid()
	if _inventory_grid == null:
		print("Inventory grid not found - using fallback")
		_inventory_grid = _create_fallback_inventory_grid()

	_blacksmith_button.pressed.connect(_on_blacksmith_pressed)
	_gemsmith_button.pressed.connect(_on_gemsmith_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)

	_equip_button.pressed.connect(_on_equip_pressed)
	_unequip_button.pressed.connect(_on_unequip_pressed)
	_socket_button.pressed.connect(_on_socket_pressed)

	_connect_equipped_slot_clicks()
	_refresh_all()


func _resolve_inventory_grid() -> GridContainer:
	var grid := get_node_or_null("MainMargin/RootVBox/InventorySection/InventoryMargin/InventoryVBox/InventoryScroll/InventoryGrid")
	if grid:
		return grid
	grid = get_node_or_null("MainMargin/MainSplit/RightPanel/Tabs/Inventory/ScrollContainer/GridContainer")
	if grid:
		return grid
	grid = get_node_or_null("MainMargin/RootVBox/InventorySection/InventoryScroll/InventoryGrid")
	if grid:
		return grid
	return null


func _create_fallback_inventory_grid() -> GridContainer:
	var inventory_parent: Node = get_node_or_null("MainMargin/RootVBox/InventorySection")
	if inventory_parent == null:
		inventory_parent = self
	var fallback_scroll := ScrollContainer.new()
	fallback_scroll.name = "FallbackInventoryScroll"
	fallback_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fallback_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fallback_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_parent.add_child(fallback_scroll)
	var fallback_grid := GridContainer.new()
	fallback_grid.name = "FallbackInventoryGrid"
	fallback_grid.columns = 6
	fallback_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback_grid.add_theme_constant_override("h_separation", 12)
	fallback_grid.add_theme_constant_override("v_separation", 12)
	fallback_scroll.add_child(fallback_grid)
	return fallback_grid


func _connect_equipped_slot_clicks() -> void:
	for display_slot in DISPLAY_SLOT_TO_RUNTIME_SLOT.keys():
		var panel: PanelContainer = get_node_or_null("MainMargin/RootVBox/TopArea/LeftPanel/EquippedSection/EquippedMargin/EquippedVBox/EquippedLayout/CoreSlots/TopRow/%s" % display_slot)
		if panel == null:
			panel = get_node_or_null("MainMargin/RootVBox/TopArea/LeftPanel/EquippedSection/EquippedMargin/EquippedVBox/EquippedLayout/CoreSlots/BottomRow/%s" % display_slot)
		if panel == null:
			panel = get_node_or_null("MainMargin/RootVBox/TopArea/LeftPanel/EquippedSection/EquippedMargin/EquippedVBox/EquippedLayout/RingColumn/%s" % display_slot)
		if panel == null:
			continue
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_equipped_slot_gui_input.bind(display_slot))


func _refresh_all() -> void:
	_refresh_equipped_display()
	_refresh_inventory_grid()
	_refresh_inspector()


func _refresh_equipped_display() -> void:
	var equipped: Dictionary = GameManager.get_equipped_map(_current_class_id)
	for display_slot in DISPLAY_SLOT_TO_RUNTIME_SLOT.keys():
		var runtime_slot: String = DISPLAY_SLOT_TO_RUNTIME_SLOT[display_slot]
		var base_label: String = DISPLAY_SLOT_LABEL[display_slot]
		var item: Dictionary = equipped.get(runtime_slot, {})
		var label_node: Label = get_node_or_null("MainMargin/RootVBox/TopArea/LeftPanel/EquippedSection/EquippedMargin/EquippedVBox/EquippedLayout/CoreSlots/TopRow/%s/Label" % display_slot)
		if label_node == null:
			label_node = get_node_or_null("MainMargin/RootVBox/TopArea/LeftPanel/EquippedSection/EquippedMargin/EquippedVBox/EquippedLayout/CoreSlots/BottomRow/%s/Label" % display_slot)
		if label_node == null:
			label_node = get_node_or_null("MainMargin/RootVBox/TopArea/LeftPanel/EquippedSection/EquippedMargin/EquippedVBox/EquippedLayout/RingColumn/%s/Label" % display_slot)
		if label_node == null:
			continue
		if item.is_empty():
			label_node.text = "%s\n(Empty)" % base_label
		else:
			label_node.text = "%s\n%s" % [base_label, str(item.get("item_name", "Equipped"))]


func _refresh_inventory_grid() -> void:
	if _inventory_grid == null:
		return
	for child in _inventory_grid.get_children():
		child.queue_free()

	var inventory_items: Array = GameManager.get_inventory_list(_current_class_id)
	var total_cells: int = maxi(42, inventory_items.size())
	for i in range(total_cells):
		var item_cell := PanelContainer.new()
		item_cell.custom_minimum_size = Vector2(90, 90)
		item_cell.mouse_filter = Control.MOUSE_FILTER_STOP

		var cell_margin := MarginContainer.new()
		cell_margin.add_theme_constant_override("margin_left", 6)
		cell_margin.add_theme_constant_override("margin_top", 6)
		cell_margin.add_theme_constant_override("margin_right", 6)
		cell_margin.add_theme_constant_override("margin_bottom", 6)
		item_cell.add_child(cell_margin)

		var cell_label := Label.new()
		cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i < inventory_items.size():
			var item: Dictionary = inventory_items[i]
			var name_text: String = str(item.get("item_name", "Gear"))
			var type_text: String = str(item.get("gear_type", str(item.get("slot_type", "Gear"))))
			var arch_text: String = str(item.get("archetype", ""))
			cell_label.text = "%s\n%s%s" % [name_text, type_text, (" / " + arch_text) if arch_text != "" else ""]
			item_cell.gui_input.connect(_on_inventory_cell_gui_input.bind(i))
		else:
			cell_label.text = "Empty"
			cell_label.add_theme_color_override("font_color", Color(0.62, 0.64, 0.69))
		cell_margin.add_child(cell_label)
		_inventory_grid.add_child(item_cell)


func _refresh_inspector() -> void:
	if _selected_item.is_empty():
		_inspector_title.text = "Item Details"
		_inspector_details.text = "Select an item from inventory to inspect."
		_equip_button.disabled = true
		_unequip_button.disabled = true
		_socket_button.disabled = true
		return

	var name_text: String = str(_selected_item.get("item_name", "Unknown"))
	var rarity_text: String = str(_selected_item.get("rarity", "normal")).capitalize()
	var gear_type: String = str(_selected_item.get("gear_type", str(_selected_item.get("slot_type", "Gear"))))
	var archetype: String = str(_selected_item.get("archetype", "Unknown"))
	var socketed: String = str(_selected_item.get("socketed_skill", ""))
	var sockets: int = int(_selected_item.get("socket_count", 0))

	_inspector_title.text = "Item Details"
	_inspector_details.text = "%s [%s / %s]\nRarity: %s\nCore: %s\nStats: %s\nSocket: %s" % [
		name_text,
		gear_type,
		archetype,
		rarity_text,
		_format_core_bonus(str(_selected_item.get("core_bonus", {}))),
		_format_stats(str(_selected_item.get("stats", {}))),
		(socketed if socketed != "" else "Empty (%d)" % sockets),
	]

	var selected_from_inventory: bool = _selected_inventory_index >= 0
	var selected_from_equipped: bool = _selected_equipped_slot_type != ""
	_equip_button.disabled = not selected_from_inventory
	_unequip_button.disabled = not selected_from_equipped

	var can_socket: bool = selected_from_equipped
	can_socket = can_socket and sockets > 0 and socketed == ""
	can_socket = can_socket and GameManager.get_loose_skill_gems(_current_class_id).size() > 0
	_socket_button.disabled = not can_socket


func _on_inventory_cell_gui_input(event: InputEvent, item_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inventory_items: Array = GameManager.get_inventory_list(_current_class_id)
		if item_index < 0 or item_index >= inventory_items.size():
			return
		_selected_inventory_index = item_index
		_selected_equipped_slot_type = ""
		_selected_item = inventory_items[item_index].duplicate(true)
		_refresh_inspector()


func _on_equipped_slot_gui_input(event: InputEvent, display_slot: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot_type: String = DISPLAY_SLOT_TO_RUNTIME_SLOT.get(display_slot, "")
		if slot_type == "":
			return
		var equipped: Dictionary = GameManager.get_equipped_map(_current_class_id)
		var item: Dictionary = equipped.get(slot_type, {})
		_selected_inventory_index = -1
		if item.is_empty():
			_selected_equipped_slot_type = ""
			_selected_item = {}
		else:
			_selected_equipped_slot_type = slot_type
			_selected_item = item.duplicate(true)
		_refresh_inspector()


func _on_equip_pressed() -> void:
	if _selected_inventory_index < 0:
		return
	var ok: bool = GameManager.equip_inventory_item(_current_class_id, _selected_inventory_index)
	print("Equip action -> ", ok)
	_selected_inventory_index = -1
	_selected_equipped_slot_type = ""
	_selected_item = {}
	_refresh_all()


func _on_unequip_pressed() -> void:
	if _selected_equipped_slot_type == "":
		return
	var ok: bool = GameManager.unequip_slot_to_inventory(_current_class_id, _selected_equipped_slot_type)
	print("Unequip action -> ", ok)
	_selected_inventory_index = -1
	_selected_equipped_slot_type = ""
	_selected_item = {}
	_refresh_all()


func _on_socket_pressed() -> void:
	if _selected_equipped_slot_type == "":
		return
	var ok: bool = GameManager.socket_first_loose_gem_into_slot(_current_class_id, _selected_equipped_slot_type)
	print("Socket action -> ", ok)
	var equipped: Dictionary = GameManager.get_equipped_map(_current_class_id)
	_selected_item = equipped.get(_selected_equipped_slot_type, {}).duplicate(true)
	_refresh_all()


func _on_blacksmith_pressed() -> void:
	var crafted: Dictionary = GameManager.gamble_gear_for_class(_current_class_id, "")
	var crafted_name: String = str(crafted.get("item_name", "Unknown Gear"))
	var crafted_type: String = str(crafted.get("gear_type", str(crafted.get("slot_type", "Gear"))))
	var crafted_archetype: String = str(crafted.get("archetype", "Unknown"))
	var sockets: int = int(crafted.get("socket_count", 0))
	print("Gambled: %s [%s / %s] - %d socket" % [crafted_name, crafted_type, crafted_archetype, sockets])
	_selected_inventory_index = -1
	_selected_equipped_slot_type = ""
	_selected_item = {}
	_refresh_all()


func _on_gemsmith_pressed() -> void:
	var infused: String = GameManager.infuse_random_unlocked_skill_gem(_current_class_id)
	print("Gemsmith infused: ", infused if infused != "" else "(none)")
	_refresh_inspector()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _format_core_bonus(raw_core: String) -> String:
	var text := raw_core.strip_edges()
	if text == "" or text == "{}":
		return "-"
	return text


func _format_stats(raw_stats: String) -> String:
	var text := raw_stats.strip_edges()
	if text == "" or text == "{}":
		return "-"
	return text
