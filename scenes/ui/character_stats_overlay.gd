extends CanvasLayer

enum ViewMode { CHARACTER, SKILL_1, SKILL_2, SKILL_3, SKILL_4 }

var _mode: int = ViewMode.CHARACTER
var _button_group: ButtonGroup

@onready var _btn_character: Button = $MainPanel/MainMargin/MainSplit/LeftPanel/CurrentCharacterButton
@onready var _btn_skill_1: Button = $MainPanel/MainMargin/MainSplit/LeftPanel/Skill1Button
@onready var _btn_skill_2: Button = $MainPanel/MainMargin/MainSplit/LeftPanel/Skill2Button
@onready var _btn_skill_3: Button = $MainPanel/MainMargin/MainSplit/LeftPanel/Skill3Button
@onready var _btn_skill_4: Button = $MainPanel/MainMargin/MainSplit/LeftPanel/Skill4Button
@onready var _btn_return: Button = $MainPanel/MainMargin/MainSplit/LeftPanel/ReturnToGameButton
@onready var _details_title: Label = $MainPanel/MainMargin/MainSplit/RightPanel/RightMargin/RightVBox/DetailsTitle
@onready var _details_text: RichTextLabel = $MainPanel/MainMargin/MainSplit/RightPanel/RightMargin/RightVBox/DetailsText


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_button_group = ButtonGroup.new()
	_btn_character.button_group = _button_group
	_btn_skill_1.button_group = _button_group
	_btn_skill_2.button_group = _button_group
	_btn_skill_3.button_group = _button_group
	_btn_skill_4.button_group = _button_group

	_btn_character.pressed.connect(_on_view_pressed.bind(ViewMode.CHARACTER))
	_btn_skill_1.pressed.connect(_on_view_pressed.bind(ViewMode.SKILL_1))
	_btn_skill_2.pressed.connect(_on_view_pressed.bind(ViewMode.SKILL_2))
	_btn_skill_3.pressed.connect(_on_view_pressed.bind(ViewMode.SKILL_3))
	_btn_skill_4.pressed.connect(_on_view_pressed.bind(ViewMode.SKILL_4))
	_btn_return.pressed.connect(_on_return_pressed)


func open_overlay() -> void:
	visible = true
	get_tree().paused = true
	_refresh_button_labels()
	_on_view_pressed(ViewMode.CHARACTER)


func _on_view_pressed(mode: int) -> void:
	_mode = mode
	_sync_toggle_state()
	_render_current_view()


func _on_return_pressed() -> void:
	visible = false
	get_tree().paused = false
	print("Character stats overlay closed (resume game)")


func _sync_toggle_state() -> void:
	_btn_character.button_pressed = (_mode == ViewMode.CHARACTER)
	_btn_skill_1.button_pressed = (_mode == ViewMode.SKILL_1)
	_btn_skill_2.button_pressed = (_mode == ViewMode.SKILL_2)
	_btn_skill_3.button_pressed = (_mode == ViewMode.SKILL_3)
	_btn_skill_4.button_pressed = (_mode == ViewMode.SKILL_4)


func _refresh_button_labels() -> void:
	var player: Node = _get_player()
	var skill_name := "None"
	if player and ("equipped_gem" in player) and player.equipped_gem:
		skill_name = str(player.equipped_gem.gem_name)
	_btn_skill_1.text = "Skill 1 - %s" % skill_name
	_btn_skill_2.text = "Skill 2 - Empty"
	_btn_skill_3.text = "Skill 3 - Empty"
	_btn_skill_4.text = "Skill 4 - Empty"


func _render_current_view() -> void:
	match _mode:
		ViewMode.CHARACTER:
			_render_character_stats()
		_:
			_render_skill_stats(_mode)


func _render_character_stats() -> void:
	var player: Node = _get_player()
	_details_title.text = "Current Character"
	if player == null:
		_details_text.text = "No player found."
		return

	var lines: PackedStringArray = []
	lines.append("[b]Core[/b]")
	lines.append("- Max HP: %s" % _read_val(player, "max_health"))
	lines.append("- Current HP: %s" % _read_val(player, "health"))
	lines.append("- Movement Speed: %s" % _read_val(player, "speed"))
	lines.append("- Attack Speed Mult: %s" % _fmt_float(_read_f(player, "stat_attack_speed_mult", 1.0)))
	lines.append("")
	lines.append("[b]Defense[/b]")
	lines.append("- Damage Reduction %%: %s%%" % _fmt_percent_from_multiplier(_read_f(player, "incoming_damage_multiplier", 1.0)))
	lines.append("- Dodge %%: %s%%" % _fmt_percent(_read_f(player, "dodge_chance", 0.0)))
	lines.append("")
	lines.append("[b]Offense[/b]")
	lines.append("- Skill Damage %%: %s%%" % _fmt_percent(_read_f(player, "stat_damage_mult", 1.0) - 1.0))
	lines.append("- Cooldown Reduction %%: %s%%" % _fmt_percent(1.0 - _read_f(player, "meta_skill_cdr_mult", 1.0)))
	lines.append("- Crit Chance %%: %s%%" % _fmt_percent(_read_f(player, "stat_crit_chance", 0.0)))
	lines.append("- Crit Damage Mult: x%s" % _fmt_float(_read_f(player, "stat_crit_damage_mult", 1.75)))
	lines.append("- Extra Projectiles: %s" % _read_val(player, "extra_projectiles"))
	lines.append("")
	lines.append("[b]Utility[/b]")
	lines.append("- XP Gain Mult: x%s" % _fmt_float(_read_f(player, "xp_gain_mult", 1.0)))
	lines.append("- Pickup Radius Mult: x%s" % _fmt_float(_read_f(player, "pickup_radius_mult", 1.0)))
	lines.append("- Area Mult: x%s" % _fmt_float(_read_f(player, "stat_area_mult", 1.0)))

	_details_text.text = "\n".join(lines)


func _render_skill_stats(mode: int) -> void:
	var player: Node = _get_player()
	if player == null:
		_details_title.text = "Skill Details"
		_details_text.text = "No player found."
		return

	if mode != ViewMode.SKILL_1:
		_details_title.text = "Skill Details"
		_details_text.text = "No skill equipped in this slot."
		return

	if not ("equipped_gem" in player) or player.equipped_gem == null:
		_details_title.text = "Skill 1"
		_details_text.text = "No equipped skill."
		return

	var gem: SkillGemResource = player.equipped_gem
	_details_title.text = "Skill 1 - %s" % gem.gem_name
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % gem.gem_name)
	lines.append("- Current Damage: %s" % _fmt_float(gem.damage * _read_f(player, "stat_damage_mult", 1.0)))
	lines.append("- Projectiles/Hits: %d" % (1 + _read_i(player, "extra_projectiles", 0)))
	lines.append("- Cooldown: %ss" % _fmt_float(gem.cooldown * _read_f(player, "meta_skill_cdr_mult", 1.0)))
	lines.append("- Area Mult: x%s" % _fmt_float(_read_f(player, "stat_area_mult", 1.0)))
	lines.append("- Duration Modifiers: Burn x%s, Rage x%s" % [
		_fmt_float(_read_f(player, "burn_debuff_output_mult", 1.0)),
		_fmt_float(_read_f(player, "berserker_rage_duration_mult", 1.0))
	])
	lines.append("")
	lines.append("[b]Active Modifiers[/b]")
	lines.append("- +%d Projectile from meta/gear" % _read_i(player, "extra_projectiles", 0))
	lines.append("- +%s%% Damage from multipliers" % _fmt_percent(_read_f(player, "stat_damage_mult", 1.0) - 1.0))
	lines.append("- %s%% Cooldown Reduction total" % _fmt_percent(1.0 - _read_f(player, "meta_skill_cdr_mult", 1.0)))
	_details_text.text = "\n".join(lines)


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _read_val(node: Node, prop: String) -> String:
	if node and (prop in node):
		return str(node.get(prop))
	return "-"


func _read_i(node: Node, prop: String, fallback: int) -> int:
	if node and (prop in node):
		return int(node.get(prop))
	return fallback


func _read_f(node: Node, prop: String, fallback: float) -> float:
	if node and (prop in node):
		return float(node.get(prop))
	return fallback


func _fmt_float(v: float) -> String:
	return str(snappedf(v, 0.01))


func _fmt_percent(v: float) -> String:
	return str(int(round(v * 100.0)))


func _fmt_percent_from_multiplier(mult: float) -> String:
	var dr := clampf(1.0 - mult, 0.0, 0.95)
	return _fmt_percent(dr)
