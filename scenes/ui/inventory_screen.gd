extends Control

var _title_label: Label
var _inventory_grid: GridContainer
var _blacksmith_button: Button
var _gemsmith_button: Button
var _main_menu_button: Button


func _ready() -> void:
	print("Inventory screen _ready() - Root children: ", get_children())
	_title_label = get_node_or_null("MainMargin/RootVBox/TitleLabel")
	_blacksmith_button = get_node_or_null("MainMargin/RootVBox/BottomBar/BlacksmithButton")
	_gemsmith_button = get_node_or_null("MainMargin/RootVBox/BottomBar/GemsmithButton")
	_main_menu_button = get_node_or_null("MainMargin/RootVBox/BottomBar/MainMenuButton")
	_inventory_grid = _resolve_inventory_grid()

	if _title_label:
		_title_label.text = "Equipment & Gems - Guardian"

	if _blacksmith_button:
		_blacksmith_button.pressed.connect(_on_blacksmith_pressed)
	if _gemsmith_button:
		_gemsmith_button.pressed.connect(_on_gemsmith_pressed)
	if _main_menu_button:
		_main_menu_button.pressed.connect(_on_main_menu_pressed)

	_populate_inventory_placeholders()


func _populate_inventory_placeholders() -> void:
	if _inventory_grid == null:
		print("Inventory grid not found - using fallback")
		_inventory_grid = _create_fallback_inventory_grid()
	if _inventory_grid == null:
		print("Inventory grid fallback failed; skipping placeholder population.")
		return

	for child in _inventory_grid.get_children():
		child.queue_free()

	for i in range(42):
		var item_cell := PanelContainer.new()
		item_cell.custom_minimum_size = Vector2(90, 90)

		var cell_margin := MarginContainer.new()
		cell_margin.add_theme_constant_override("margin_left", 6)
		cell_margin.add_theme_constant_override("margin_top", 6)
		cell_margin.add_theme_constant_override("margin_right", 6)
		cell_margin.add_theme_constant_override("margin_bottom", 6)
		item_cell.add_child(cell_margin)

		var cell_label := Label.new()
		cell_label.text = "Empty"
		cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell_margin.add_child(cell_label)

		_inventory_grid.add_child(item_cell)


func _resolve_inventory_grid() -> GridContainer:
	# Current scene structure (from latest remake).
	var grid := get_node_or_null("MainMargin/RootVBox/InventorySection/InventoryMargin/InventoryVBox/InventoryScroll/InventoryGrid")
	if grid:
		return grid

	# User-requested fallback/legacy structure.
	grid = get_node_or_null("MainMargin/MainSplit/RightPanel/Tabs/Inventory/ScrollContainer/GridContainer")
	if grid:
		return grid

	grid = get_node_or_null("MainMargin/RootVBox/InventorySection/InventoryScroll/InventoryGrid")
	if grid:
		return grid

	print("Inventory grid not found - using fallback")
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


func _on_blacksmith_pressed() -> void:
	print("Blacksmith button pressed")


func _on_gemsmith_pressed() -> void:
	print("Gemsmith button pressed")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
