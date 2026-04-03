extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/basic_enemy.tscn")
const ENEMY_FAST_SCENE: PackedScene = preload("res://entities/enemies/fast_enemy.tscn")
const ENEMY_TANK_SCENE: PackedScene = preload("res://entities/enemies/tanky_enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/boss_enemy.tscn")
const CHEST_SCENE: PackedScene = preload("res://entities/run_chest.tscn")
const XP_ORB_SCENE: PackedScene = preload("res://entities/xp_orb.tscn")
const SKELETON_SCENE: PackedScene = preload("res://entities/minions/skeleton.tscn")
const WOLF_SCENE: PackedScene = preload("res://entities/minions/wolf.tscn")
const RUN_HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const END_RUN_SCENE: PackedScene = preload("res://scenes/ui/end_run_screen.tscn")
const LOOT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/world_loot_popup.tscn")
const MAX_RUN_SECONDS: float = 1800.0
## Full survival (30 min) meta XP bonus, added on top of time/kills formula.
const META_XP_FULL_RUN_BONUS: int = 250
const ON_CLASS_DROP_CHANCE: float = 0.85

@export var spawn_radius: float = 760.0
@export var max_enemies: int = 30
@export var max_chests_on_map: int = 8

var enemy_count: int = 0
var total_kills: int = 0
var run_time_s: float = 0.0
## Chests: timed by active movement only (never blocked by enemy cap).
var _chest_move_seconds: float = 0.0
var _chest_next_interval: float = 20.0
var _boss_10_spawned: bool = false
var _boss_20_spawned: bool = false
var _boss_final_spawned: bool = false
var _run_ended: bool = false
var _damage_by_skill: Dictionary = {}
var _last_spawn_center: Vector2 = Vector2.ZERO
var _catchup_cooldown: float = 0.0
## How long the player has sustained movement in ~same direction (for spawn pressure).
var _heading_streak: float = 0.0
var _last_heading: Vector2 = Vector2.ZERO
var _active_skeletons: Array[CharacterBody2D] = []
var _active_wolves: Array[CharacterBody2D] = []
var _active_raised_dead: Array[CharacterBody2D] = []

var pause_menu: Node = null
var level_up_ui: Node = null
var level_up_pending: bool = false
var run_hud: CanvasLayer = null
var end_run_screen: CanvasLayer = null
var gm_menu_layer: CanvasLayer = null
var gm_menu_panel: PanelContainer = null
var _gm_menu_open: bool = false

@onready var enemies_node: Node2D = $Enemies
@onready var _player: CharacterBody2D = $Player
@onready var _backdrop: Node2D = $Backdrop
@onready var _parallax_wash: ColorRect = $Backdrop/ParallaxWash


func _ready() -> void:
	add_to_group("run_arena")
	add_to_group("arena")
	GameManager.is_in_run = true
	print("Infinite Run Arena loaded")
	if _backdrop:
		print("Backdrop: repeating grass + parallax wash (infinite feel)")
	if _player:
		_last_spawn_center = _player.global_position
	_chest_next_interval = randf_range(20.0, 30.0)
	print("Arena: chest timer target ", snappedf(_chest_next_interval, 0.1), "s movement until first roll")
	run_hud = RUN_HUD_SCENE.instantiate()
	run_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(run_hud)
	end_run_screen = END_RUN_SCENE.instantiate()
	end_run_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(end_run_screen)
	if end_run_screen.has_signal("replay_pressed"):
		end_run_screen.replay_pressed.connect(_on_end_run_replay_pressed)
	if end_run_screen.has_signal("equipment_pressed"):
		end_run_screen.equipment_pressed.connect(_on_end_run_equipment_pressed)
	if end_run_screen.has_signal("menu_pressed"):
		end_run_screen.menu_pressed.connect(_on_end_run_menu_pressed)

	if not has_node("PauseMenu"):
		var pause_scene: Resource = load("res://scenes/ui/pause_menu.tscn")
		if pause_scene:
			pause_menu = pause_scene.instantiate()
			add_child(pause_menu)
			pause_menu.visible = false
			print("Pause menu created")
		else:
			print("WARNING: Pause menu scene not found")
	else:
		pause_menu = $PauseMenu

	var lu_scene: Resource = load("res://scenes/ui/level_up_screen.tscn")
	if lu_scene:
		level_up_ui = lu_scene.instantiate()
		add_child(level_up_ui)
		level_up_ui.visible = false
		if level_up_ui.has_signal("buff_selected"):
			level_up_ui.buff_selected.connect(_on_level_buff_selected)
		print("Level up screen created")
	else:
		print("WARNING: Level up screen not found")
	_create_gm_menu()


func _create_gm_menu() -> void:
	gm_menu_layer = CanvasLayer.new()
	gm_menu_layer.name = "GMMenuLayer"
	gm_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gm_menu_layer)

	gm_menu_panel = PanelContainer.new()
	gm_menu_panel.name = "GMMenuPanel"
	gm_menu_panel.visible = false
	gm_menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	gm_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	gm_menu_panel.focus_mode = Control.FOCUS_ALL
	gm_menu_panel.gui_input.connect(_on_gm_panel_gui_input)
	gm_menu_panel.anchor_left = 0.5
	gm_menu_panel.anchor_top = 0.5
	gm_menu_panel.anchor_right = 0.5
	gm_menu_panel.anchor_bottom = 0.5
	gm_menu_panel.offset_left = -200.0
	gm_menu_panel.offset_top = -160.0
	gm_menu_panel.offset_right = 200.0
	gm_menu_panel.offset_bottom = 160.0
	gm_menu_layer.add_child(gm_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	gm_menu_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "GM Debug Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)

	var xp_btn := Button.new()
	xp_btn.text = "Give 500 Meta EXP"
	xp_btn.pressed.connect(_on_gm_give_meta_exp)
	vb.add_child(xp_btn)

	var points_btn := Button.new()
	points_btn.text = "Give 5 Meta Skill Points"
	points_btn.pressed.connect(_on_gm_give_meta_points)
	vb.add_child(points_btn)

	var mats_btn := Button.new()
	mats_btn.text = "Give 10 Crafting Materials"
	mats_btn.pressed.connect(_on_gm_give_materials)
	vb.add_child(mats_btn)

	var gear_btn := Button.new()
	gear_btn.text = "Give Random Normal Gear"
	gear_btn.pressed.connect(_on_gm_give_random_gear)
	vb.add_child(gear_btn)

	var resume_btn := Button.new()
	resume_btn.text = "Resume Game"
	resume_btn.pressed.connect(_on_gm_resume_pressed)
	vb.add_child(resume_btn)


func _process(_delta: float) -> void:
	if _run_ended:
		return
	if get_tree().paused:
		return
	run_time_s += _delta
	_catchup_cooldown = maxf(0.0, _catchup_cooldown - _delta)
	_update_parallax_wash()
	_update_heading_streak(_delta)
	_update_run_hud()
	_update_boss_schedule()
	_update_chest_spawns(_delta)
	if run_time_s >= MAX_RUN_SECONDS:
		end_run(true)
		return

	var streak_mult: float = 1.0 + minf(1.35, _heading_streak / 850.0)
	var target_spawn_rate: float = (1.0 + (float(total_kills) / 45.0)) * streak_mult
	if enemy_count < max_enemies and randf() < target_spawn_rate * 0.042:
		spawn_enemy()
	if enemy_count < max_enemies and randf() < target_spawn_rate * 0.018:
		spawn_enemy()
	if enemy_count < max_enemies and randf() < (streak_mult - 1.0) * 0.055:
		spawn_enemy()
	_maybe_spawn_catchup_group()


func _update_heading_streak(delta: float) -> void:
	if _player == null or not _player is CharacterBody2D:
		return
	var v: Vector2 = (_player as CharacterBody2D).velocity
	if v.length_squared() < 420.0:
		_heading_streak = maxf(0.0, _heading_streak - delta * 220.0)
		return
	var dir := v.normalized()
	if _last_heading.length_squared() < 0.01:
		_last_heading = dir
	if dir.dot(_last_heading) > 0.86:
		_heading_streak += v.length() * delta
		_heading_streak = minf(_heading_streak, 3200.0)
	else:
		_heading_streak *= 0.55
		_last_heading = dir


func _update_parallax_wash() -> void:
	if _parallax_wash == null or _player == null:
		return
	# Wash scrolls opposite to player motion in world space (camera follows player).
	var p := _player.global_position
	_parallax_wash.position = Vector2(-12000.0, -12000.0) + p * 0.07


func _update_run_hud() -> void:
	if run_hud and run_hud.has_method("set_timer_text"):
		run_hud.call("set_timer_text", _format_time(run_time_s))
	if run_hud and run_hud.has_method("set_kills_line"):
		run_hud.call("set_kills_line", total_kills, enemy_count, max_enemies)
	if run_hud and run_hud.has_method("set_meta_exp_bar"):
		var class_id: String = _run_class_id()
		var meta: Dictionary = MetaProgression.get_meta_level_data_for_class(class_id)
		run_hud.call("set_meta_exp_bar", int(meta.get("level", 1)), int(meta.get("exp", 0)), int(meta.get("next", 1000)))
	if run_hud and run_hud.has_method("set_skill_cast_state") and _player and is_instance_valid(_player):
		var skill_name := "Basic Attack"
		var auto_cast := true
		if "equipped_gem" in _player and _player.equipped_gem:
			skill_name = str(_player.equipped_gem.gem_name)
			auto_cast = bool(_player.equipped_gem.auto_cast)
		run_hud.call("set_skill_cast_state", skill_name, auto_cast)
	var boss := _get_first_live_boss()
	if boss and run_hud and run_hud.has_method("set_boss_bar"):
		run_hud.call("set_boss_bar", str(boss.get("boss_name")), int(boss.get("health")), int(boss.get("max_health")), true)
	elif run_hud and run_hud.has_method("set_boss_bar"):
		run_hud.call("set_boss_bar", "", 0, 1, false)


func on_player_skill_used(skill_name: String) -> void:
	if run_hud and run_hud.has_method("show_skill_popup"):
		run_hud.call("show_skill_popup", skill_name)


func summon_skeletons_for_player(caster: Node2D, class_id: String, summon_count: int = 3, base_cap: int = 6, necro_cap_bonus: int = 0) -> void:
	if caster == null or SKELETON_SCENE == null:
		return
	_prune_dead_skeletons()
	var effective_cap: int = base_cap
	if class_id == "Necromancer":
		effective_cap += maxi(0, necro_cap_bonus)
	var can_spawn: int = maxi(0, effective_cap - _active_skeletons.size())
	var to_spawn: int = mini(summon_count, can_spawn)
	for i in range(to_spawn):
		var s := SKELETON_SCENE.instantiate() as CharacterBody2D
		if s == null:
			continue
		var angle := randf() * TAU
		var dist := randf_range(28.0, 56.0)
		s.global_position = caster.global_position + Vector2.from_angle(angle) * dist
		add_child(s)
		_active_skeletons.append(s)
		s.tree_exited.connect(_on_skeleton_exited.bind(s))
	print("Summoned ", to_spawn, " skeletons. Current count: ", _active_skeletons.size(), "/", effective_cap)


func _prune_dead_skeletons() -> void:
	var kept: Array[CharacterBody2D] = []
	for s in _active_skeletons:
		if s != null and is_instance_valid(s):
			kept.append(s)
	_active_skeletons = kept


func _on_skeleton_exited(skel: CharacterBody2D) -> void:
	_active_skeletons.erase(skel)


func summon_wolves_for_player(caster: Node2D, summon_count: int = 2, lifetime_seconds: float = 12.0) -> void:
	if caster == null or WOLF_SCENE == null:
		return
	_prune_dead_wolves()
	for i in range(maxi(0, summon_count)):
		var w := WOLF_SCENE.instantiate() as CharacterBody2D
		if w == null:
			continue
		w.set("lifetime_seconds", lifetime_seconds)
		var angle := randf() * TAU
		var dist := randf_range(24.0, 58.0)
		w.global_position = caster.global_position + Vector2.from_angle(angle) * dist
		add_child(w)
		_active_wolves.append(w)
		w.tree_exited.connect(_on_wolf_exited.bind(w))
	print("Summoned ", summon_count, " wolves. Active wolves: ", _active_wolves.size(), " (lasting 12s each)")


func _prune_dead_wolves() -> void:
	var kept: Array[CharacterBody2D] = []
	for w in _active_wolves:
		if w != null and is_instance_valid(w):
			kept.append(w)
	_active_wolves = kept


func _on_wolf_exited(wolf: CharacterBody2D) -> void:
	_active_wolves.erase(wolf)


func summon_raised_dead_for_player(caster: Node2D, summon_count: int = 1, hard_cap: int = 3) -> void:
	if caster == null or SKELETON_SCENE == null:
		return
	_prune_dead_raised_dead()
	var can_spawn: int = maxi(0, hard_cap - _active_raised_dead.size())
	var to_spawn: int = mini(maxi(0, summon_count), can_spawn)
	for i in range(to_spawn):
		var s := SKELETON_SCENE.instantiate() as CharacterBody2D
		if s == null:
			continue
		s.set("max_health", 80)
		s.set("health", 80)
		s.set("contact_damage", 20)
		s.set("contact_cooldown", 1.2)
		s.modulate = Color(0.78, 0.86, 1.0, 1.0)
		var angle := randf() * TAU
		var dist := randf_range(24.0, 54.0)
		s.global_position = caster.global_position + Vector2.from_angle(angle) * dist
		add_child(s)
		_active_raised_dead.append(s)
		s.tree_exited.connect(_on_raised_dead_exited.bind(s))
	print("Raised dead summoned: ", to_spawn, ". Current raised dead: ", _active_raised_dead.size(), "/", hard_cap)


func _prune_dead_raised_dead() -> void:
	var kept: Array[CharacterBody2D] = []
	for s in _active_raised_dead:
		if s != null and is_instance_valid(s):
			kept.append(s)
	_active_raised_dead = kept


func _on_raised_dead_exited(minion: CharacterBody2D) -> void:
	_active_raised_dead.erase(minion)


func _update_boss_schedule() -> void:
	if run_time_s >= 600.0 and not _boss_10_spawned:
		_boss_10_spawned = true
		_spawn_boss("Mini-Boss: Night Stalker", 1400, 95.0, 20)
	if run_time_s >= 1200.0 and not _boss_20_spawned:
		_boss_20_spawned = true
		_spawn_boss("Mini-Boss: Blood Sentinel", 2400, 105.0, 24)
	if run_time_s >= 1770.0 and not _boss_final_spawned:
		_boss_final_spawned = true
		_spawn_boss("Final Boss: Crimson Overlord", 5200, 118.0, 30)


func _spawn_boss(boss_title: String, hp: int, move_spd: float, dmg: int) -> void:
	if _player == null:
		return
	var b: CharacterBody2D = BOSS_SCENE.instantiate() as CharacterBody2D
	b.set("boss_name", boss_title)
	b.set("max_health", hp)
	b.set("speed", move_spd)
	b.set("contact_damage", dmg)
	var angle := randf() * TAU
	var dist := spawn_radius + 260.0
	b.global_position = _player.global_position + Vector2.from_angle(angle) * dist
	enemies_node.add_child(b)
	enemy_count += 1
	print("Boss spawned: ", boss_title, " at ", _format_time(run_time_s))


func _update_chest_spawns(delta: float) -> void:
	if _player == null:
		return
	# Only advance timer while the player is actually moving (velocity threshold).
	var moving := false
	if _player is CharacterBody2D:
		moving = (_player as CharacterBody2D).velocity.length_squared() > 90.0
	if moving:
		_chest_move_seconds += delta
		# Avoid huge catch-up bursts after long stalls / debugger pauses.
		_chest_move_seconds = minf(_chest_move_seconds, _chest_next_interval * 1.35)
	if _chest_move_seconds >= _chest_next_interval:
		_chest_move_seconds -= _chest_next_interval
		_try_spawn_chest()
		_chest_next_interval = randf_range(20.0, 30.0)


func _try_spawn_chest() -> void:
	if _player == null:
		return
	var on_map := get_tree().get_nodes_in_group("run_chests").size()
	if on_map >= max_chests_on_map:
		return
	var c: Area2D = CHEST_SCENE.instantiate() as Area2D
	c.add_to_group("run_chests")
	var angle := randf() * TAU
	var dist := randf_range(400.0, 840.0)
	c.global_position = _player.global_position + Vector2.from_angle(angle) * dist
	add_child(c)
	print("Chest spawned (", on_map + 1, "/", max_chests_on_map, " on map).")


func spawn_enemy() -> void:
	var player := _player as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	_spawn_enemy_with_profile(player, _pick_spawn_angle(player), "")


func _spawn_enemy_with_profile(player: Node2D, angle: float, force_type: String) -> void:
	var distance := spawn_radius + randf_range(50.0, 290.0)
	var pos := player.global_position + Vector2.from_angle(angle) * distance
	_spawn_enemy_at(pos, force_type, player)


func _resolve_enemy_scene(force_type: String) -> Array:
	var enemy_type := force_type
	if enemy_type == "":
		var roll := randf()
		if roll < 0.58:
			enemy_type = "normal"
		elif roll < 0.82:
			enemy_type = "fast"
		else:
			enemy_type = "tanky"
	var scene: PackedScene = ENEMY_SCENE
	match enemy_type:
		"fast":
			scene = ENEMY_FAST_SCENE
		"tanky":
			scene = ENEMY_TANK_SCENE
		_:
			scene = ENEMY_SCENE
	return [scene, enemy_type]


func _spawn_enemy_at(pos: Vector2, force_type: String, player: Node2D) -> void:
	if enemy_count >= max_enemies:
		return
	var pair: Array = _resolve_enemy_scene(force_type)
	var scene: PackedScene = pair[0]
	var enemy_type: String = str(pair[1])
	var enemy: Node2D = scene.instantiate() as Node2D
	enemy.global_position = pos
	enemies_node.add_child(enemy)
	enemy_count += 1
	if player:
		_last_spawn_center = player.global_position
	print("Spawned ", enemy_type, " enemy (count=", enemy_count, ", kills=", total_kills, ")")


func _pick_spawn_angle(player: Node2D) -> float:
	# Uniform ring around player, blended toward movement direction (pressure ahead / flanks).
	var uniform := randf() * TAU
	var forward := _player_forward_dir(player)
	var forward_angle := forward.angle()
	var cone := forward_angle + (randf() - 0.5) * PI * 1.35
	return lerp_angle(uniform, cone, 0.52)


func _player_forward_dir(player: Node2D) -> Vector2:
	if player is CharacterBody2D:
		var v := (player as CharacterBody2D).velocity
		if v.length_squared() > 64.0:
			return v.normalized()
	if player.has_node("Visual"):
		return Vector2.RIGHT.rotated((player.get_node("Visual") as Node2D).rotation)
	return Vector2.RIGHT


func _maybe_spawn_catchup_group() -> void:
	if _player == null:
		return
	if _catchup_cooldown > 0.0:
		return
	if _player.global_position.distance_to(_last_spawn_center) <= 380.0:
		return
	var group_count := mini(6, max_enemies - enemy_count)
	if group_count <= 0:
		return
	var forward := _player_forward_dir(_player)
	var hub := _player.global_position + forward * randf_range(660.0, 940.0)
	for i in range(group_count):
		var ang := forward.angle() + randf_range(-0.7, 0.7)
		var rad := randf_range(36.0, 220.0)
		var spot := hub + Vector2.from_angle(ang) * rad
		var kind := "fast" if i < 2 else ("tanky" if i == group_count - 1 and randf() < 0.55 else "normal")
		_spawn_enemy_at(spot, kind, _player)
	_catchup_cooldown = 1.75
	print("Catch-up pack spawned ahead (", group_count, " enemies) — player pushed toward new area")


func on_enemy_died(at: Vector2) -> void:
	# Deferred from basic_enemy — safe to mutate; still defer orb spawn to avoid edge cases with query flush.
	enemy_count = maxi(0, enemy_count - 1)
	total_kills += 1
	print("Enemy defeated. Count=", enemy_count, " total kills=", total_kills)
	call_deferred("_deferred_spawn_xp_orb", at)


func _deferred_spawn_xp_orb(at: Vector2) -> void:
	if _run_ended or not XP_ORB_SCENE:
		return
	var orb: Node2D = XP_ORB_SCENE.instantiate() as Node2D
	orb.global_position = at
	add_child(orb)


func on_boss_died(boss_title: String, at: Vector2, _source: String = "boss") -> void:
	enemy_count = maxi(0, enemy_count - 1)
	total_kills += 1
	print("Boss defeated: ", boss_title)
	call_deferred("_deferred_drop_boss_rewards", at)


func _deferred_drop_boss_rewards(at: Vector2) -> void:
	_drop_boss_rewards(at)


func open_chest(at: Vector2, _source: String = "chest") -> void:
	print("Chest opened at ", at, " (normal quality gear roll)")
	var popup_lines: PackedStringArray = []
	var dropped_item: Dictionary = _drop_weighted_gear_to_inventory("chest")
	if not dropped_item.is_empty():
		popup_lines.append("Gained %s" % str(dropped_item.get("item_name", "Gear")))
	var mats: int = 1 + randi() % 3
	_drop_common_materials(at, mats)
	popup_lines.append("Gained %d Crafting Materials" % mats)
	if randf() < 0.03:
		_drop_exp_magnet()
		popup_lines.append("Received Exp Magnet")
	if randf() < 0.02:
		var gem_name := _roll_random_unlocked_skill_gem()
		print("Very rare chest roll: socketed skill gem -> ", gem_name)
		popup_lines.append("Received %s Gem" % gem_name)
	if randf() < 0.015:
		var class_key := _run_class_id()
		GameManager.add_blank_gems(class_key, 1)
		popup_lines.append("Received Blank Gem")
		print("Chest drop: Blank Gem for class ", class_key)
	if LOOT_POPUP_SCENE:
		var pop: Node = LOOT_POPUP_SCENE.instantiate()
		if pop.has_method("setup"):
			pop.setup(at, popup_lines)
			add_child(pop)


func _drop_boss_rewards(at: Vector2) -> void:
	print("Boss loot drop: higher quality gear + materials + gem chance")
	_drop_weighted_gear_to_inventory("boss")
	_drop_common_materials(at, 6 + randi() % 4)
	for i in range(8):
		var orb: Node2D = XP_ORB_SCENE.instantiate() as Node2D
		orb.global_position = at + Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
		add_child(orb)
	if randf() < 0.30:
		print("Boss dropped socketed skill gem -> ", _roll_random_unlocked_skill_gem())
	if randf() < 0.35:
		var class_key2 := _run_class_id()
		GameManager.add_blank_gems(class_key2, 1)
		print("Boss dropped Blank Gem for class ", class_key2)


func _drop_common_materials(at: Vector2, amount: int) -> void:
	for i in range(amount):
		var orb: Node2D = XP_ORB_SCENE.instantiate() as Node2D
		orb.global_position = at + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		orb.set("xp_value", 6 + randi() % 10)
		add_child(orb)


func _drop_exp_magnet() -> void:
	print("EXP Magnet drop! Pulling nearby XP into player.")
	if _player == null:
		return
	for n in get_tree().get_nodes_in_group("xp_orb"):
		if n is Node2D and (n as Node2D).global_position.distance_to(_player.global_position) < 1200.0:
			(n as Node2D).global_position = _player.global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))


func _drop_weighted_gear_to_inventory(drop_source: String) -> Dictionary:
	var class_key: String = _run_class_id()
	if class_key == "":
		print("Dropped gear skipped: missing current class")
		return {}
	var class_archetype: String = GameManager.get_archetype_for_class(class_key)
	var chosen_archetype: String = class_archetype
	if randf() > ON_CLASS_DROP_CHANCE:
		var off_classes := [GameManager.ARCHETYPE_HEAVY, GameManager.ARCHETYPE_LIGHT, GameManager.ARCHETYPE_ARCANE]
		off_classes.erase(class_archetype)
		chosen_archetype = str(off_classes[randi() % off_classes.size()])
	var item: Dictionary = GameManager.gamble_gear_for_class(class_key, "", chosen_archetype)
	print(
		"Dropped gear: ",
		str(item.get("item_name", "Unknown Gear")),
		" [",
		chosen_archetype,
		"] for player class: ",
		class_key,
		" (source=",
		drop_source,
		")"
	)
	return item


func _roll_random_unlocked_skill_gem() -> String:
	var class_id := ""
	if GameManager.current_class:
		class_id = GameManager.current_class.character_class_name
	if class_id == "":
		return "Basic Skill Gem"
	var tree := MetaProgression.Catalog.get_tree(class_id)
	var unlocked := MetaProgression.get_unlocked_list(class_id)
	var options: Array = []
	for row in tree.get("nodes", []):
		var kind := str(row.get("kind", ""))
		var id := str(row.get("id", ""))
		if kind in [MetaProgression.Catalog.KIND_CENTER, MetaProgression.Catalog.KIND_CORNER] and id in unlocked:
			options.append(str(row.get("title", "Skill Gem")))
	if options.is_empty():
		return "Basic Skill Gem"
	return str(options[randi() % options.size()])


func record_skill_damage(skill_name: String, amount: int) -> void:
	if skill_name == "" or amount <= 0:
		return
	_damage_by_skill[skill_name] = int(_damage_by_skill.get(skill_name, 0)) + amount


func _format_time(seconds_total: float) -> String:
	var s: int = int(seconds_total)
	return "%02d:%02d" % [s / 60, s % 60]


func _run_class_id() -> String:
	return GameManager.get_current_class_key()


func _compute_meta_xp_for_run() -> int:
	var t_sec: int = int(floor(run_time_s))
	var gain: int = t_sec * 2 + total_kills * 10
	if run_time_s >= MAX_RUN_SECONDS - 0.05:
		gain += META_XP_FULL_RUN_BONUS
		print("Meta XP: full run bonus +", META_XP_FULL_RUN_BONUS)
	return gain


func _get_first_live_boss() -> CharacterBody2D:
	for n in get_tree().get_nodes_in_group("bosses"):
		if n is CharacterBody2D and is_instance_valid(n):
			return n as CharacterBody2D
	return null


func end_run(success: bool) -> void:
	var reason: String = "Time limit reached" if success else "Player died"
	if _run_ended:
		return
	_run_ended = true
	var ended_via_pause_menu: bool = (pause_menu != null and pause_menu.visible and not success)
	GameManager.is_in_run = false
	_gm_menu_open = false
	if gm_menu_panel:
		gm_menu_panel.visible = false
	get_tree().paused = true
	var run_class: String = _run_class_id()
	var meta_gain: int = _compute_meta_xp_for_run()
	MetaProgression.add_meta_xp(meta_gain, run_class)
	print("Meta EXP gained on run end: ", meta_gain, " for class ", run_class)
	var meta: Dictionary = {"level": 1, "exp": 0, "next": 120}
	if run_class != "":
		meta = MetaProgression.get_meta_level_data_for_class(run_class)
	var class_points: int = 0
	if run_class != "":
		class_points = MetaProgression.get_points(run_class)
	var rows: Array = []
	for k in _damage_by_skill.keys():
		rows.append({"skill": str(k), "damage": int(_damage_by_skill[k])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["damage"]) > int(b["damage"]))
	var end_title := "Defeated" if not success else "Run Complete"
	print("Run ended. Time: ", _format_time(run_time_s), " Kills: ", total_kills, " Meta EXP awarded: ", meta_gain)
	if ended_via_pause_menu:
		print("Run ended via pause menu. Meta EXP awarded: ", meta_gain)
	print("Run ended: ", reason, " | time=", _format_time(run_time_s), " kills=", total_kills, " meta_gain=", meta_gain, " class=", run_class)
	if end_run_screen and end_run_screen.has_method("show_results"):
		end_run_screen.call(
			"show_results",
			_format_time(run_time_s),
			total_kills,
			rows,
			run_class,
			int(meta["level"]),
			int(meta["exp"]),
			int(meta["next"]),
			class_points,
			meta_gain,
			end_title
		)


func _end_run(reason: String) -> void:
	# Backward-compatible wrapper for older call sites.
	end_run(reason != "Player died")


func request_open_level_up_if_needed(player: Node) -> void:
	if _run_ended:
		return
	if level_up_ui == null or not is_instance_valid(player):
		return
	if level_up_ui.visible:
		print("Level up UI already open; pending choices=", _read_pending(player))
		return
	level_up_pending = true
	get_tree().paused = true
	level_up_ui.show_level_up_choices()
	print("Paused for level up. Pending choices for player: ", _read_pending(player))


func _on_level_buff_selected(buff_id: String, buff_title: String, _rarity: String) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		if level_up_ui and level_up_ui.has_method("hide_level_up"):
			level_up_ui.hide_level_up()
		level_up_pending = false
		get_tree().paused = false
		return

	if player.has_method("apply_level_buff_by_id"):
		player.call("apply_level_buff_by_id", buff_id)
	elif player.has_method("apply_level_buff"):
		player.call("apply_level_buff", buff_id)
	print("Applied buff: ", buff_title)

	var pending: int = 0
	if player.has_method("consume_pending_level_up"):
		pending = int(player.call("consume_pending_level_up"))
	print("Remaining level-up choices: ", pending)

	if pending > 0:
		level_up_ui.show_level_up_choices()
	else:
		if level_up_ui.has_method("hide_level_up"):
			level_up_ui.hide_level_up()
		level_up_pending = false
		if pause_menu and not pause_menu.visible:
			get_tree().paused = false
			print("Unpaused after all level-up picks")


func toggle_pause() -> void:
	if pause_menu == null:
		return
	if level_up_pending:
		pause_menu.visible = not pause_menu.visible
		print("Pause menu toggled during level-up (tree.paused stays true)")
		return
	var becoming_paused: bool = not get_tree().paused
	get_tree().paused = becoming_paused
	pause_menu.visible = becoming_paused
	print("Pause toggled → paused=", becoming_paused)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_toggle_gm_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func _toggle_gm_menu() -> void:
	if gm_menu_panel == null:
		return
	_gm_menu_open = not _gm_menu_open
	gm_menu_panel.visible = _gm_menu_open
	if _gm_menu_open:
		get_tree().paused = true
		gm_menu_panel.grab_focus()
		print("GM menu opened")
	else:
		if level_up_pending:
			get_tree().paused = true
		elif pause_menu and pause_menu.visible:
			get_tree().paused = true
		else:
			get_tree().paused = false
		print("GM menu closed")


func _on_gm_give_meta_exp() -> void:
	var class_key := _run_class_id()
	MetaProgression.add_meta_xp(500, class_key)
	print("GM: gave 500 Meta EXP to class ", class_key)


func _on_gm_give_meta_points() -> void:
	var class_key := _run_class_id()
	MetaProgression.add_points(class_key, 5)
	print("GM: gave 5 Meta Skill Points to class ", class_key)


func _on_gm_give_materials() -> void:
	if _player == null:
		return
	_drop_common_materials(_player.global_position, 10)
	print("GM: gave 10 Crafting Materials")


func _on_gm_give_random_gear() -> void:
	var class_key := _run_class_id()
	var archetype := GameManager.get_archetype_for_class(class_key)
	var item: Dictionary = GameManager.gamble_gear_for_class(class_key, "", archetype)
	print("GM: gave random normal gear -> ", item.get("item_name", "?"), " [", archetype, "] for class ", class_key)


func _on_gm_resume_pressed() -> void:
	if _gm_menu_open:
		_toggle_gm_menu()


func _on_gm_panel_gui_input(event: InputEvent) -> void:
	if not _gm_menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_toggle_gm_menu()


func on_pause_resume_pressed() -> void:
	if level_up_pending:
		print("Resume: level-up flow active — keeping game paused")
		return
	get_tree().paused = false


func on_player_died() -> void:
	if _run_ended:
		return
	level_up_pending = false
	if level_up_ui and level_up_ui.has_method("hide_level_up"):
		level_up_ui.hide_level_up()
	if pause_menu:
		pause_menu.visible = false
	end_run(false)


func _read_pending(player: Node) -> int:
	if player and player.has_method("get_pending_level_ups"):
		return int(player.call("get_pending_level_ups"))
	return 0


func _on_end_run_replay_pressed() -> void:
	get_tree().paused = false
	GameManager.mark_next_run_as_new()
	get_tree().change_scene_to_file("res://scenes/run_arena/run_arena.tscn")


func _on_end_run_equipment_pressed() -> void:
	get_tree().paused = false
	GameManager.is_in_run = false
	get_tree().change_scene_to_file("res://scenes/ui/inventory_screen.tscn")


func _on_end_run_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.is_in_run = false
	get_tree().change_scene_to_file("res://main.tscn")
