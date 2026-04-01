extends CharacterBody2D

@export var speed: float = 450.0
@export var max_health_base: int = 120
var max_health: int = 120
var health: int = 120
var attack_timer: float = 0.0
var equipped_gem: SkillGemResource
var _last_move_dir: Vector2 = Vector2.RIGHT
var _is_dead: bool = false

## Progression
var level: int = 1
var xp: int = 0
var xp_to_next: int = 50
var pending_level_ups: int = 0

## Level-up stat scaling (early-game tuned)
var stat_damage_mult: float = 1.0
var stat_projectile_speed_mult: float = 1.0
var stat_attack_speed_mult: float = 1.0
var stat_area_mult: float = 1.0
var move_speed_level_mult: float = 1.0
var stat_crit_chance: float = 0.0
var stat_crit_damage_mult: float = 1.75
var extra_projectiles: int = 0
var double_damage_attacks_remaining: int = 0
var incoming_damage_multiplier: float = 1.0
var dodge_chance: float = 0.0
var invuln_seconds_after_hit: float = 0.0
var _invulnerability_timer: float = 0.0
var xp_gain_mult: float = 1.0
var pickup_radius_mult: float = 1.0
## Flat % of max HP healed per second (stacks from regen buffs).
var health_regen_pct_of_max_per_sec: float = 0.0
var temporary_gem_slots: int = 0
var global_cdr_buff_timer: float = 0.0

## Class-themed upgrade hooks
var guardian_bash_damage_mult: float = 1.0
var guardian_knockback_mult: float = 1.0
var berserker_rage_duration_mult: float = 1.0
var burn_debuff_output_mult: float = 1.0
var assassin_shadow_cooldown_mult: float = 1.0
var ranger_extra_volley_arrows: int = 0
## If >= 0, overrides default Holy Smite heal fraction.
var paladin_smite_heal_fraction: float = -1.0
var druid_thorn_slow_factor: float = 0.52
var necromancer_bone_extra_pierce: int = 0
var summon_cap_bonus: int = 0

## Skill-state timers for unique behaviors (aura/channel/transforms).
var _iron_ward_time: float = 0.0
var _blood_cry_time: float = 0.0
var _berserk_mode_time: float = 0.0
var _rapid_fire_time: float = 0.0
var _smoke_bomb_time: float = 0.0
var _holy_avenger_time: float = 0.0
var _bear_form_time: float = 0.0
var _wolf_form_time: float = 0.0
var _death_mark_time: float = 0.0

## Permanent meta skill tree (merged per class in _ready)
var meta_skill_cdr_mult: float = 1.0
var meta_damage_while_rage_mult: float = 1.0
var meta_low_hp_move_mult: float = 1.0
var meta_melee_range_mult: float = 1.0
var meta_holy_damage_mult: float = 1.0
var meta_thorn_damage_mult: float = 1.0
var meta_bone_lifesteal_add: int = 0

## Always-on class fantasy (not level-up). See meta tree for skill unlocks.
var class_passive_paladin_heal_nova_ratio: float = 0.0
var class_passive_guardian_low_hp_dr: float = 0.0
var class_passive_berserker_low_hp_damage: float = 0.0

## Rage Slash: faster attack timer countdown while active.
var _rage_haste_time: float = 0.0
var _attack_timer_haste_mult: float = 1.0

## Shadow Strike: brief move speed boost.
var _shadow_move_time: float = 0.0

@onready var health_bar: ProgressBar = $HealthBar


func _ready():
	print("=== PLAYER LOADED ===")
	add_to_group("player")
	max_health = max_health_base
	health = max_health
	xp_to_next = _xp_for_next_level()
	equipped_gem = create_starting_gem()
	if GameManager.current_class:
		var cid := GameManager.current_class.character_class_name
		var is_new_run: bool = GameManager.consume_next_run_is_new()
		GameManager.give_starting_weapon_if_needed(cid, is_new_run)
		_apply_meta_tree_modifiers(cid)
		_apply_unique_class_passive(cid)
		_apply_equipment_modifiers(cid)
		var gear_gem: SkillGemResource = GameManager.get_equipped_skill_gem_for_class(cid)
		if gear_gem:
			equipped_gem = gear_gem
			print("Loaded socketed gear gem: ", equipped_gem.gem_name)
	_sync_health_bar()
	print("XP to next level: ", xp_to_next)


func create_starting_gem() -> SkillGemResource:
	var gem := SkillGemResource.new()
	var class_name_str: String = ""
	if GameManager.current_class:
		class_name_str = GameManager.current_class.character_class_name

	match class_name_str:
		"Guardian":
			gem.gem_name = "Holy Shield Bash"
			gem.damage = 25.0
			gem.cooldown = 1.2
		"Berserker":
			gem.gem_name = "Rage Slash"
			gem.damage = 35.0
			gem.cooldown = 0.7
		"Elementalist":
			gem.gem_name = "Fireball"
			gem.damage = 22.0
			gem.cooldown = 0.9
		"Assassin":
			gem.gem_name = "Shadow Strike"
			gem.damage = 40.0
			gem.cooldown = 1.1
		"Ranger":
			gem.gem_name = "Arrow Volley"
			gem.damage = 20.0
			gem.cooldown = 0.65
		"Paladin":
			gem.gem_name = "Holy Smite"
			gem.damage = 28.0
			gem.cooldown = 1.0
		"Druid":
			gem.gem_name = "Thorn Burst"
			gem.damage = 18.0
			gem.cooldown = 1.4
		"Necromancer":
			gem.gem_name = "Bone Spear"
			gem.damage = 24.0
			gem.cooldown = 0.8
		_:
			gem.gem_name = "Basic Attack"
			gem.damage = 20.0
			gem.cooldown = 1.0

	gem.gem_type = "projectile"
	return gem


func _apply_meta_tree_modifiers(class_id: String) -> void:
	if class_id == "":
		return
	var agg: Dictionary = MetaProgression.aggregate_bonuses(class_id)
	var mh: int = int(agg.get("max_health_flat", 0))
	if mh != 0:
		max_health += mh
		health += mh
	incoming_damage_multiplier *= float(agg.get("incoming_damage_mult", 1.0))
	guardian_knockback_mult *= float(agg.get("knockback_mult", 1.0))
	stat_area_mult *= float(agg.get("area_mult", 1.0))
	berserker_rage_duration_mult *= float(agg.get("rage_build_mult", 1.0))
	meta_damage_while_rage_mult = float(agg.get("damage_while_rage_mult", 1.0))
	meta_low_hp_move_mult = float(agg.get("low_hp_move_mult", 1.0))
	meta_melee_range_mult = float(agg.get("melee_range_mult", 1.0))
	stat_projectile_speed_mult *= float(agg.get("projectile_speed_mult", 1.0))
	meta_skill_cdr_mult = float(agg.get("cdr_mult", 1.0))
	stat_crit_chance = mini(0.95, stat_crit_chance + float(agg.get("crit_chance_add", 0.0)) + float(agg.get("distant_crit_add", 0.0)))
	stat_crit_damage_mult *= float(agg.get("crit_damage_mult", 1.0)) * float(agg.get("backstab_mult", 1.0))
	extra_projectiles += int(agg.get("extra_projectiles", 0))
	if class_id == "Elementalist":
		stat_damage_mult *= float(agg.get("elem_damage_mult", 1.0))
	burn_debuff_output_mult *= float(agg.get("burn_duration_mult", 1.0))
	if class_id == "Ranger":
		move_speed_level_mult *= float(agg.get("kite_move_mult", 1.0))
	meta_holy_damage_mult = float(agg.get("holy_damage_mult", 1.0))
	var sadd: float = float(agg.get("smite_heal_add", 0.0))
	if sadd > 0.0:
		if paladin_smite_heal_fraction < 0.0:
			paladin_smite_heal_fraction = 0.5 + sadd
		else:
			paladin_smite_heal_fraction += sadd
	druid_thorn_slow_factor /= float(agg.get("slow_strength_mult", 1.0))
	meta_thorn_damage_mult = float(agg.get("thorn_damage_mult", 1.0))
	necromancer_bone_extra_pierce += int(agg.get("pierce_add", 0))
	meta_bone_lifesteal_add = int(agg.get("lifesteal_add", 0))
	summon_cap_bonus = int(agg.get("summon_count_add", 0))
	print("Meta tree modifiers applied for ", class_id, " (CDR x", snappedf(meta_skill_cdr_mult, 0.01), ", melee reach x", snappedf(meta_melee_range_mult, 0.01), ")")


func _apply_equipment_modifiers(class_id: String) -> void:
	if class_id == "":
		return
	var totals: Dictionary = GameManager.get_equipment_stat_totals(class_id)
	var hp_add: int = int(totals.get("max_health_flat", 0))
	if hp_add > 0:
		max_health += hp_add
		health += hp_add
	var spd_add: int = int(totals.get("move_speed_flat", 0))
	if spd_add != 0:
		speed += float(spd_add)
	var dmg_add: int = int(totals.get("damage_flat", 0))
	if dmg_add > 0:
		stat_damage_mult *= (1.0 + float(dmg_add) * 0.02)
	var armor_add: int = int(totals.get("armor_flat", 0))
	if armor_add > 0:
		incoming_damage_multiplier *= clampf(1.0 - float(armor_add) * 0.01, 0.65, 1.0)
	var dr_pct: float = float(totals.get("dr_pct", 0.0))
	if dr_pct > 0.0:
		incoming_damage_multiplier *= maxf(0.35, 1.0 - dr_pct)
	var move_pct: float = float(totals.get("move_speed_pct", 0.0))
	if move_pct > 0.0:
		speed *= (1.0 + move_pct)
	var atk_spd_pct: float = float(totals.get("attack_speed_pct", 0.0))
	if atk_spd_pct > 0.0:
		stat_attack_speed_mult *= (1.0 + atk_spd_pct)
	var skill_dmg_pct: float = float(totals.get("skill_damage_pct", 0.0))
	if skill_dmg_pct > 0.0:
		stat_damage_mult *= (1.0 + skill_dmg_pct)
	var cdr_pct: float = float(totals.get("cdr_pct", 0.0))
	if cdr_pct > 0.0:
		meta_skill_cdr_mult *= maxf(0.55, 1.0 - cdr_pct)
	print("Equipment modifiers applied for ", class_id, " => ", totals)


func _apply_unique_class_passive(class_id: String) -> void:
	if class_id == "":
		return
	match class_id:
		"Paladin":
			class_passive_paladin_heal_nova_ratio = 0.05
			print("Class passive [Paladin]: Radiance — 5% of all healing becomes AoE holy damage (scales with meta holy damage).")
		"Guardian":
			class_passive_guardian_low_hp_dr = 0.12
			print("Class passive [Guardian]: Bulwark — below 50% HP, take 12% less damage from hits.")
		"Berserker":
			class_passive_berserker_low_hp_damage = 0.15
			print("Class passive [Berserker]: Blood Fury — below 50% HP, deal 15% more damage.")
		"Elementalist":
			burn_debuff_output_mult *= 1.12
			print("Class passive [Elementalist]: Wildfire — burn damage over time is 12% stronger.")
		"Assassin":
			stat_crit_chance = mini(0.92, stat_crit_chance + 0.10)
			print("Class passive [Assassin]: Predator's Eye — +10% critical strike chance.")
		"Ranger":
			move_speed_level_mult *= 1.12
			print("Class passive [Ranger]: Strider — +12% movement speed.")
		"Druid":
			health_regen_pct_of_max_per_sec += 0.0035
			print("Class passive [Druid]: Verdant Heart — +0.35% max HP regeneration per second.")
		"Necromancer":
			stat_projectile_speed_mult *= 1.10
			print("Class passive [Necromancer]: Grave Momentum — +10% projectile speed.")
		_:
			print("Class passive: no entry for '", class_id, "'")


func _class_passive_paladin_holy_nova(damage: int) -> void:
	if damage <= 0 or _is_dead:
		return
	var r := 210.0
	var hit: int = 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n):
			continue
		if n is Node2D and (n as Node2D).global_position.distance_to(global_position) > r:
			continue
		if n.has_method("take_damage"):
			n.call("take_damage", maxi(1, damage))
			hit += 1
	if hit > 0:
		print("Paladin passive Radiance: nova hit ", hit, " enemies for ", damage, " each")


func _melee_reach() -> float:
	return MELEE_RANGE * meta_melee_range_mult


func _xp_for_next_level() -> int:
	return int(36 + level * 32)


func get_pending_level_ups() -> int:
	return pending_level_ups


func consume_pending_level_up() -> int:
	pending_level_ups = maxi(0, pending_level_ups - 1)
	return pending_level_ups


func add_xp(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	var gained: int = int(round(float(amount) * xp_gain_mult))
	xp += gained
	print("Gained ", gained, " XP (raw ", amount, ", mult ", snappedf(xp_gain_mult, 0.01), ") → ", xp, " / ", xp_to_next, " (Lv ", level, ")")
	while xp >= xp_to_next and not _is_dead:
		xp -= xp_to_next
		level += 1
		xp_to_next = _xp_for_next_level()
		pending_level_ups += 1
		print("Level threshold reached! Character level ", level, ". Pick an upgrade. (queued: ", pending_level_ups, ")")
	if pending_level_ups > 0:
		call_deferred("_request_level_up_ui")


func _request_level_up_ui() -> void:
	get_tree().call_group("run_arena", "request_open_level_up_if_needed", self)


func apply_level_buff_by_id(buff_id: String) -> void:
	## Sync with res://scripts/level_up/level_up_buff_catalog.gd — BUFF_ROWS.
	match buff_id:
		# Offensive
		"o_c_dmg_20":
			stat_damage_mult *= 1.2
		"o_c_aspd_15":
			stat_attack_speed_mult *= 1.15
		"o_c_pspd_25":
			stat_projectile_speed_mult *= 1.25
		"o_c_crit_30":
			stat_crit_chance += 0.30
		"o_u_dmg_35":
			stat_damage_mult *= 1.35
		"o_u_aspd_25":
			stat_attack_speed_mult *= 1.25
		"o_u_proj_1":
			extra_projectiles += 1
		"o_u_crit_dmg_50":
			stat_crit_damage_mult *= 1.5
		"o_e_dmg_50":
			stat_damage_mult *= 1.5
		"o_e_aspd_40":
			stat_attack_speed_mult *= 1.4
		"o_e_proj_2":
			extra_projectiles += 2
		"o_e_double_3":
			double_damage_attacks_remaining += 3
		# Defensive
		"d_c_hp_40":
			max_health += 40
			health += 40
		"d_c_hp_pct_25":
			max_health = int(round(float(max_health) * 1.25))
			health = mini(max_health, int(round(float(health) * 1.25)))
		"d_c_move_15":
			move_speed_level_mult *= 1.15
		"d_c_dr_20":
			incoming_damage_multiplier *= 0.8
		"d_u_hp_80":
			max_health += 80
			health += 80
		"d_u_hp_pct_35":
			max_health = int(round(float(max_health) * 1.35))
			health = mini(max_health, int(round(float(health) * 1.35)))
		"d_u_move_25":
			move_speed_level_mult *= 1.25
		"d_u_dr_30":
			incoming_damage_multiplier *= 0.7
		"d_u_dodge_15":
			dodge_chance = mini(0.5, dodge_chance + 0.15)
		"d_e_hp_120":
			max_health += 120
			health += 120
		"d_e_hp_pct_50":
			max_health = int(round(float(max_health) * 1.5))
			health = mini(max_health, int(round(float(health) * 1.5)))
		"d_e_move_40":
			move_speed_level_mult *= 1.4
		"d_e_dr_40":
			incoming_damage_multiplier *= 0.6
		"d_e_invuln_3":
			invuln_seconds_after_hit = maxf(invuln_seconds_after_hit, 3.0)
		# Utility / special
		"s_c_xp_30":
			xp_gain_mult *= 1.3
		"s_c_pickup_40":
			pickup_radius_mult *= 1.4
		"s_c_area_20":
			stat_area_mult *= 1.2
		"s_c_regen_15":
			health_regen_pct_of_max_per_sec += 0.0045
		"s_u_xp_50":
			xp_gain_mult *= 1.5
		"s_u_pickup_80":
			pickup_radius_mult *= 1.8
		"s_u_area_35":
			stat_area_mult *= 1.35
		"s_u_regen_25":
			health_regen_pct_of_max_per_sec += 0.0075
		"s_e_xp_80":
			xp_gain_mult *= 1.8
		"s_e_pickup_150":
			pickup_radius_mult *= 2.5
		"s_e_area_60":
			stat_area_mult *= 1.6
		"s_e_full_heal_max":
			max_health = int(round(float(max_health) * 1.2))
			health = max_health
		"s_e_cdr_30":
			global_cdr_buff_timer = 30.0
		_:
			print("Unknown buff id: ", buff_id, " — add to catalog + player match.")
			return
	_sync_health_bar()


## Legacy hook (older saves / tests)
func apply_level_buff(buff_key: String) -> void:
	apply_level_buff_by_id(buff_key)


func get_effective_pickup_radius() -> float:
	return 26.0 * pickup_radius_mult


func _cooldown_after_cast() -> float:
	var cd: float = equipped_gem.cooldown
	if equipped_gem and equipped_gem.gem_name == "Shadow Strike":
		cd *= assassin_shadow_cooldown_mult
	cd *= meta_skill_cdr_mult
	if global_cdr_buff_timer > 0.0:
		cd *= 0.6
	return cd


func _roll_outgoing_damage(base_scaled: int) -> int:
	var out: int = base_scaled
	var was_crit: bool = false
	var cc: float = mini(0.95, stat_crit_chance)
	if cc > 0.0 and randf() < cc:
		out = int(round(float(out) * stat_crit_damage_mult))
		was_crit = true
	if double_damage_attacks_remaining > 0:
		out *= 2
	if class_passive_berserker_low_hp_damage > 0.0 and max_health > 0:
		if float(health) / float(max_health) <= 0.5:
			out = int(round(float(out) * (1.0 + class_passive_berserker_low_hp_damage)))
	if was_crit:
		print("Critical strike! Final damage ", out)
	return out


func _dmg_scaled(base: float, melee_extra: float = 1.0) -> int:
	return int(round(base * melee_extra * stat_damage_mult * _skill_temp_damage_mult()))


func _skill_temp_damage_mult() -> float:
	var mult: float = 1.0
	if _blood_cry_time > 0.0:
		mult *= 1.30
	if _berserk_mode_time > 0.0:
		mult *= 1.45
	if _holy_avenger_time > 0.0:
		mult *= 1.28
	if _bear_form_time > 0.0:
		mult *= 1.18
	if _wolf_form_time > 0.0:
		mult *= 1.15
	if _death_mark_time > 0.0:
		mult *= 1.25
	return mult


func _skill_temp_move_mult() -> float:
	var mult: float = 1.0
	if _berserk_mode_time > 0.0:
		mult *= 1.12
	if _wolf_form_time > 0.0:
		mult *= 1.35
	if _bear_form_time > 0.0:
		mult *= 0.86
	return mult


func _skill_temp_attack_speed_mult() -> float:
	var mult: float = 1.0
	if _rapid_fire_time > 0.0:
		mult *= 1.65
	if _wolf_form_time > 0.0:
		mult *= 1.18
	return mult


func _skill_temp_damage_taken_mult() -> float:
	var mult: float = 1.0
	if _iron_ward_time > 0.0:
		mult *= 0.82
	if _holy_avenger_time > 0.0:
		mult *= 0.85
	if _bear_form_time > 0.0:
		mult *= 0.72
	if _berserk_mode_time > 0.0:
		mult *= 1.35
	if _smoke_bomb_time > 0.0:
		mult *= 0.90
	return mult


func _gem_projectile_color(gem_name: String) -> Color:
	match gem_name:
		"Fireball":
			return Color(1.0, 0.35, 0.08)
		"Holy Smite":
			return Color(1.0, 0.95, 0.45)
		"Shadow Strike":
			return Color(0.55, 0.2, 0.85)
		"Shield Bash", "Holy Shield Bash":
			return Color(0.35, 0.65, 1.0)
		"Rage Slash":
			return Color(1.0, 0.15, 0.2)
		"Arrow Shot", "Arrow Volley":
			return Color(0.45, 0.75, 0.35)
		"Thorn Burst":
			return Color(0.2, 0.85, 0.35)
		"Bone Dart", "Bone Spear":
			return Color(0.72, 0.78, 0.88)
		"Basic Attack":
			return Color(1.0, 0.85, 0.35)
		_:
			return Color(1.0, 0.85, 0.25)


func get_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not n is Node2D:
			continue
		var n2 := n as Node2D
		var d2 := global_position.distance_squared_to(n2.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n2
	return best


func _base_aim_dir() -> Vector2:
	var t := get_nearest_enemy()
	if t:
		return (t.global_position - global_position).normalized()
	return Vector2.RIGHT.rotated($Visual.rotation)


func _physics_process(delta: float):
	if _is_dead:
		return

	if global_cdr_buff_timer > 0.0:
		global_cdr_buff_timer -= delta

	if _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta

	if health_regen_pct_of_max_per_sec > 0.0 and health < max_health:
		var reg: float = float(max_health) * health_regen_pct_of_max_per_sec * delta
		if reg >= 1.0:
			heal(int(reg))

	if _rage_haste_time > 0.0:
		_rage_haste_time -= delta
		_attack_timer_haste_mult = 1.38
	else:
		_attack_timer_haste_mult = 1.0

	_iron_ward_time = maxf(0.0, _iron_ward_time - delta)
	_blood_cry_time = maxf(0.0, _blood_cry_time - delta)
	_berserk_mode_time = maxf(0.0, _berserk_mode_time - delta)
	_rapid_fire_time = maxf(0.0, _rapid_fire_time - delta)
	_smoke_bomb_time = maxf(0.0, _smoke_bomb_time - delta)
	_holy_avenger_time = maxf(0.0, _holy_avenger_time - delta)
	_bear_form_time = maxf(0.0, _bear_form_time - delta)
	_wolf_form_time = maxf(0.0, _wolf_form_time - delta)
	_death_mark_time = maxf(0.0, _death_mark_time - delta)

	var move_mult: float = 1.0
	if _shadow_move_time > 0.0:
		_shadow_move_time -= delta
		move_mult = 1.24
	move_mult *= _skill_temp_move_mult()
	if max_health > 0 and float(health) / float(max_health) <= 0.35:
		move_mult *= meta_low_hp_move_mult

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed * move_speed_level_mult * move_mult
	move_and_slide()

	if direction.length_squared() > 0.0001:
		_last_move_dir = direction.normalized()

	var nearest := get_nearest_enemy()
	if nearest:
		var to_enemy := nearest.global_position - global_position
		if to_enemy.length_squared() > 0.0001:
			$Visual.rotation = to_enemy.angle()
	elif direction.length_squared() > 0.0001:
		$Visual.rotation = _last_move_dir.angle()

	attack_timer -= delta * _attack_timer_haste_mult * stat_attack_speed_mult * _skill_temp_attack_speed_mult()
	if attack_timer <= 0.0 and equipped_gem:
		attack_timer = _cooldown_after_cast()
		perform_class_specific_attack()


const MELEE_RANGE: float = 90.0


func perform_class_specific_attack() -> void:
	if not equipped_gem:
		return

	var gname: String = equipped_gem.gem_name
	print("Attacking with ", gname)
	print("Skill used: ", gname)
	get_tree().call_group("run_arena", "on_player_skill_used", gname)

	# Skill categories:
	# - melee / dash / strike
	# - projectile / chain / explode
	# - ground_aoe / aura / zone
	# - channel / transformation / summon
	match gname:
		# Guardian
		"Shield Bash", "Holy Shield Bash":
			_perform_melee_attack_named("Holy Shield Bash")
		"Heavy Slam":
			_perform_heavy_slam()
		"Iron Ward":
			_cast_iron_ward()
		"Judgment":
			_cast_judgment()
		"Guardian's Wall":
			_cast_guardians_wall()
		# Berserker
		"Rage Slash":
			_perform_melee_attack_named("Rage Slash")
		"Blood Cry":
			_cast_blood_cry()
		"Frenzied Charge":
			_cast_frenzied_charge()
		"Reckless Swing":
			_cast_reckless_swing()
		"Berserk Mode":
			_cast_berserk_mode()
		# Elementalist
		"Fireball":
			_spawn_fireball()
		"Lightning Chain":
			_cast_lightning_chain()
		"Frost Nova":
			_cast_frost_nova()
		"Elemental Overload":
			_cast_elemental_overload()
		"Meteor":
			_cast_meteor()
		# Assassin
		"Shadow Strike":
			_cast_shadow_teleport_strike()
		"Poison Dagger":
			_cast_poison_dagger()
		"Smoke Bomb":
			_cast_smoke_bomb()
		"Backstab":
			_cast_backstab()
		"Death Mark":
			_cast_death_mark()
		# Ranger
		"Arrow Volley":
			_perform_arrow_volley()
		"Explosive Arrow":
			_cast_explosive_arrow()
		"Multishot":
			_cast_multishot()
		"Trap Deployment":
			_cast_trap_deployment()
		"Rapid Fire":
			_cast_rapid_fire()
		# Paladin
		"Holy Smite":
			_spawn_holy_smite()
		"Consecrated Ground":
			_cast_consecrated_ground()
		"Divine Strike":
			_perform_melee_attack_named("Divine Strike")
		"Lay on Hands":
			_cast_lay_on_hands()
		"Holy Avenger":
			_cast_holy_avenger()
		# Druid
		"Thorn Burst":
			_perform_thorn_burst()
		"Bear Form":
			_cast_bear_form()
		"Wolf Form":
			_cast_wolf_form()
		"Vine Prison":
			_cast_vine_prison()
		"Nature's Wrath":
			_cast_natures_wrath()
		# Necromancer
		"Bone Spear":
			_spawn_bone_spear()
		"Summon Skeletons":
			_perform_summon_skeletons()
		"Corpse Explosion":
			_cast_corpse_explosion()
		"Life Drain":
			_cast_life_drain()
		"Raise Dead":
			_cast_raise_dead()
		"Summon Wolves":
			_perform_summon_wolves()
		_:
			_spawn_default_projectile()
	_consume_double_damage_swing()


func _perform_summon_skeletons() -> void:
	var class_id: String = ""
	if GameManager.current_class:
		class_id = str(GameManager.current_class.character_class_name)
	get_tree().call_group("run_arena", "summon_skeletons_for_player", self, class_id, 3, 6, summon_cap_bonus)


func _perform_summon_wolves() -> void:
	get_tree().call_group("run_arena", "summon_wolves_for_player", self, 2, 12.0)


func _cast_heavy_hit_with_slow(mult: float, slow_factor: float, slow_time: float) -> void:
	var nearest := get_nearest_enemy()
	if nearest == null or global_position.distance_to(nearest.global_position) > _melee_reach() * 1.15:
		return
	var dmg: int = _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * mult))
	nearest.call("take_damage", dmg)
	if nearest.has_method("apply_slow"):
		nearest.call("apply_slow", slow_time, slow_factor)


func _cast_heavy_slam() -> void:
	_play_melee_slash_vfx(Color(0.9, 0.84, 0.7), 16.0, 102.0)
	_cast_heavy_hit_with_slow(1.55, 0.6, 1.6)


func _cast_iron_ward() -> void:
	_iron_ward_time = 8.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node2D and (n as Node2D).global_position.distance_to(global_position) < 240.0 and n.has_method("apply_slow"):
			n.call("apply_slow", 1.2, 0.75)


func _cast_judgment() -> void:
	var target := get_nearest_enemy()
	var pos := target.global_position if target else global_position + _base_aim_dir() * 80.0
	_spawn_instant_aoe_at(pos, 160.0, _dmg_scaled(equipped_gem.damage * 1.25), "Judgment")


func _cast_guardians_wall() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node2D:
			var d := (n as Node2D).global_position.distance_to(global_position)
			if d < 200.0 and n.has_method("apply_knockback"):
				n.call("apply_knockback", global_position, 300.0)
	_invulnerability_timer = maxf(_invulnerability_timer, 0.8)


func _cast_blood_cry() -> void:
	_blood_cry_time = 8.0


func _cast_frenzied_charge() -> void:
	var dir := _base_aim_dir()
	global_position += dir * 120.0
	_shadow_move_time = maxf(_shadow_move_time, 0.8)
	var nearest := get_nearest_enemy()
	if nearest and global_position.distance_to(nearest.global_position) < 120.0:
		nearest.call("take_damage", _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * 1.3)))


func _cast_reckless_swing() -> void:
	_play_melee_slash_vfx(Color(1.0, 0.35, 0.3), 18.0, 118.0)
	_cast_heavy_hit_with_slow(1.9, 0.9, 0.4)
	# self recoil, but intentionally non-lethal
	health = maxi(1, health - 8)
	_sync_health_bar()


func _cast_berserk_mode() -> void:
	_berserk_mode_time = 10.0


func _cast_lightning_chain() -> void:
	var first := get_nearest_enemy()
	if first == null:
		return
	var hit_positions: Array[Vector2] = [first.global_position]
	var current: Node2D = first
	var total_hits := 4
	for i in range(total_hits):
		if current and current.has_method("take_damage"):
			current.call("take_damage", _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * 0.92)))
		var next_target: Node2D = null
		var best_d2: float = INF
		for n in get_tree().get_nodes_in_group("enemies"):
			if not (n is Node2D) or n == current:
				continue
			var n2 := n as Node2D
			var d2 := current.global_position.distance_squared_to(n2.global_position)
			if d2 < best_d2 and d2 <= 240.0 * 240.0:
				best_d2 = d2
				next_target = n2
		current = next_target
		if current == null:
			break
		hit_positions.append(current.global_position)


func _cast_frost_nova() -> void:
	_spawn_instant_aoe_at(global_position, 170.0, _dmg_scaled(equipped_gem.damage), "Frost Nova", 0.45, 2.2)


func _cast_elemental_overload() -> void:
	var pick := randi() % 3
	if pick == 0:
		_spawn_fireball()
	elif pick == 1:
		_cast_lightning_chain()
	else:
		_cast_frost_nova()


func _cast_meteor() -> void:
	var target := get_nearest_enemy()
	var pos := target.global_position if target else (global_position + _base_aim_dir() * 180.0)
	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func():
		if _is_dead:
			return
		_spawn_instant_aoe_at(pos, 210.0, _dmg_scaled(equipped_gem.damage * 1.7), "Meteor", 0.7, 2.0)
	)


func _cast_shadow_teleport_strike() -> void:
	var t := get_nearest_enemy()
	if t == null:
		return
	var dir := (t.global_position - global_position).normalized()
	global_position = t.global_position - dir * 18.0
	_perform_melee_attack_named("Shadow Strike")


func _cast_poison_dagger() -> void:
	var nearest := get_nearest_enemy()
	if nearest == null:
		return
	if global_position.distance_to(nearest.global_position) > _melee_reach():
		return
	var dmg := _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * 1.05))
	nearest.call("take_damage", dmg)
	if nearest.has_method("apply_burn"):
		nearest.call("apply_burn", 3.0, 1.0)


func _cast_smoke_bomb() -> void:
	_smoke_bomb_time = 6.0


func _cast_backstab() -> void:
	var nearest := get_nearest_enemy()
	if nearest == null:
		return
	if global_position.distance_to(nearest.global_position) > _melee_reach() * 1.1:
		return
	var dmg := _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * 2.0))
	nearest.call("take_damage", dmg)


func _cast_death_mark() -> void:
	_death_mark_time = 6.0
	var nearest := get_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		nearest.call("take_damage", _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * 0.5)))


func _cast_explosive_arrow() -> void:
	var target := get_nearest_enemy()
	var pos := target.global_position if target else (global_position + _base_aim_dir() * 160.0)
	_spawn_instant_aoe_at(pos, 130.0, _dmg_scaled(equipped_gem.damage * 1.2), "Explosive Arrow")


func _cast_multishot() -> void:
	var base := _base_aim_dir()
	var dmg := _dmg_scaled(equipped_gem.damage * 0.65)
	for i in range(5 + extra_projectiles):
		var spread := (float(i) - float((5 + extra_projectiles) - 1) * 0.5) * 0.06
		_spawn_projectile(base.rotated(spread), dmg, 560.0, 3.7, 0.9, _gem_projectile_color("Arrow Volley"))


func _cast_trap_deployment() -> void:
	var pos := global_position + _base_aim_dir() * 120.0
	_spawn_instant_aoe_at(pos, 130.0, _dmg_scaled(equipped_gem.damage), "Trap Deployment", 0.55, 2.4)


func _cast_rapid_fire() -> void:
	_rapid_fire_time = 4.5


func _cast_consecrated_ground() -> void:
	_spawn_instant_aoe_at(global_position, 180.0, _dmg_scaled(equipped_gem.damage * 0.9), "Consecrated Ground", 0.75, 1.4)
	heal(maxi(1, int(round(float(max_health) * 0.08))))


func _cast_lay_on_hands() -> void:
	heal(maxi(12, int(round(float(max_health) * 0.22))))


func _cast_holy_avenger() -> void:
	_holy_avenger_time = 9.0


func _cast_bear_form() -> void:
	_bear_form_time = 10.0


func _cast_wolf_form() -> void:
	_wolf_form_time = 9.0
	_perform_summon_wolves()


func _cast_vine_prison() -> void:
	var target := get_nearest_enemy()
	var pos := target.global_position if target else global_position + _base_aim_dir() * 110.0
	_spawn_instant_aoe_at(pos, 150.0, _dmg_scaled(equipped_gem.damage * 1.05), "Vine Prison", 0.4, 2.6)


func _cast_natures_wrath() -> void:
	_cast_lightning_chain()
	_cast_vine_prison()


func _cast_corpse_explosion() -> void:
	var target := get_nearest_enemy()
	var pos := target.global_position if target else global_position + _base_aim_dir() * 90.0
	_spawn_instant_aoe_at(pos, 155.0, _dmg_scaled(equipped_gem.damage * 1.35), "Corpse Explosion")


func _cast_life_drain() -> void:
	var target := get_nearest_enemy()
	if target == null:
		return
	if target.has_method("take_damage"):
		var dmg := _roll_outgoing_damage(_dmg_scaled(equipped_gem.damage * 0.85))
		target.call("take_damage", dmg)
		heal(maxi(1, int(round(float(dmg) * 0.35))))


func _cast_raise_dead() -> void:
	get_tree().call_group("run_arena", "summon_raised_dead_for_player", self, 1, 3)


func _spawn_instant_aoe_at(pos: Vector2, radius: float, damage: int, skill_name: String, slow_factor: float = 1.0, slow_duration: float = 0.0) -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		var n2 := n as Node2D
		if n2.global_position.distance_to(pos) > radius:
			continue
		if n2.has_method("take_damage"):
			n2.call("take_damage", _roll_outgoing_damage(damage))
		if slow_duration > 0.0 and n2.has_method("apply_slow"):
			n2.call("apply_slow", slow_duration, slow_factor)
	get_tree().call_group("run_arena", "record_skill_damage", skill_name, damage)


func _consume_double_damage_swing() -> void:
	if double_damage_attacks_remaining > 0:
		double_damage_attacks_remaining -= 1
		print("Double-damage swings left: ", double_damage_attacks_remaining)


func _spawn_projectile(
		aim_dir: Vector2,
		base_damage: int,
		spd: float = 480.0,
		life: float = 4.5,
		scales: float = 1.28,
		col: Color = Color.WHITE,
		burn_sec: float = 0.0,
		pierce_hits: int = 1,
		holy_frac: float = 0.0,
		steal: int = 0,
		burn_tick_mult: float = 1.0
	) -> void:
	var projectile_scene := preload("res://gems/projectiles/basic_projectile.tscn")
	var p: Area2D = projectile_scene.instantiate() as Area2D
	var dir := aim_dir.normalized()
	p.global_position = global_position + dir * 28.0
	p.direction = dir
	p.damage = _roll_outgoing_damage(base_damage)
	p.projectile_color = col
	p.speed = spd * stat_projectile_speed_mult
	p.max_lifetime = life
	p.scale_mult = scales
	p.burn_duration = burn_sec
	p.pierce_hits_remaining = maxi(1, pierce_hits)
	p.holy_heal_fraction = holy_frac
	p.life_steal_flat = steal
	p.burn_tick_damage_mult = burn_tick_mult
	p.source_skill = equipped_gem.gem_name
	get_parent().add_child(p)


func _spawn_projectile_volley(aim_dir: Vector2, base_damage: int, spd: float, life: float, scales: float, col: Color) -> void:
	_spawn_projectile(aim_dir, base_damage, spd, life, scales, col, 0.0, 1, 0.0, 0, 1.0)


func _spawn_ranged_with_duplicates(
		aim_dir: Vector2,
		base_damage: int,
		spd: float,
		life: float,
		scales: float,
		col: Color,
		burn_sec: float,
		pierce_hits: int,
		holy_frac: float,
		steal: int,
		burn_tick_mult: float
	) -> void:
	var total: int = 1 + maxi(0, extra_projectiles)
	for i in total:
		var off: float = (float(i) - float(total - 1) * 0.5) * 0.075
		_spawn_projectile(
			aim_dir.rotated(off),
			base_damage,
			spd,
			life,
			scales,
			col,
			burn_sec,
			pierce_hits,
			holy_frac,
			steal,
			burn_tick_mult
		)


func _spawn_fireball() -> void:
	var d := _dmg_scaled(equipped_gem.damage)
	_spawn_ranged_with_duplicates(
		_base_aim_dir(),
		d,
		430.0,
		4.8,
		1.34,
		_gem_projectile_color("Fireball"),
		2.15,
		1,
		0.0,
		0,
		burn_debuff_output_mult
	)


func _spawn_holy_smite() -> void:
	var d := int(round(float(_dmg_scaled(equipped_gem.damage)) * meta_holy_damage_mult))
	var hf: float = 0.5 if paladin_smite_heal_fraction < 0.0 else paladin_smite_heal_fraction
	_spawn_ranged_with_duplicates(
		_base_aim_dir(),
		d,
		395.0,
		5.2,
		1.42,
		_gem_projectile_color("Holy Smite"),
		0.0,
		1,
		hf,
		0,
		1.0
	)


func _spawn_bone_spear() -> void:
	var d := _dmg_scaled(equipped_gem.damage * 1.05)
	var pierce: int = 8 + necromancer_bone_extra_pierce
	_spawn_ranged_with_duplicates(
		_base_aim_dir(),
		d,
		655.0,
		5.5,
		0.78,
		_gem_projectile_color("Bone Spear"),
		0.0,
		pierce,
		0.0,
		3 + maxi(0, meta_bone_lifesteal_add),
		1.0
	)


func _spawn_default_projectile() -> void:
	var d := _dmg_scaled(equipped_gem.damage)
	var gn := equipped_gem.gem_name
	_spawn_ranged_with_duplicates(
		_base_aim_dir(),
		d,
		480.0,
		4.5,
		1.22,
		_gem_projectile_color(gn),
		0.0,
		1,
		0.0,
		0,
		1.0
	)


func _perform_arrow_volley() -> void:
	var base := _base_aim_dir()
	var dmg := _dmg_scaled(equipped_gem.damage * 0.72)
	var col := _gem_projectile_color("Arrow Volley")
	var n: int = 3 + ranger_extra_volley_arrows
	for i in n:
		var spread: float = (float(i) - float(n - 1) * 0.5) * 0.11
		_spawn_projectile_volley(base.rotated(spread), dmg, 505.0, 3.9, 0.9, col)


func _perform_thorn_burst() -> void:
	var target := get_nearest_enemy()
	var pos: Vector2
	if target:
		pos = target.global_position
	else:
		pos = global_position + _base_aim_dir() * 52.0
		print("Thorn Burst: no target, casting ahead")

	var aoe := preload("res://gems/aoe/thorn_burst_aoe.tscn").instantiate() as Node2D
	aoe.global_position = pos
	aoe.scale = Vector2.ONE * stat_area_mult
	aoe.set("slow_factor", druid_thorn_slow_factor)
	if "damage" in aoe:
		var base_thorn: float = 12.0 + equipped_gem.damage * 0.12
		var td: int = int(round(base_thorn * stat_damage_mult * stat_area_mult * meta_thorn_damage_mult))
		if double_damage_attacks_remaining > 0:
			td *= 2
		aoe.set("damage", td)
		get_tree().call_group("run_arena", "record_skill_damage", "Thorn Burst", td)
	get_parent().add_child(aoe)
	print("Thorn Burst AoE at ", pos, " (area mult=", snappedf(stat_area_mult, 0.01), ")")


func _perform_melee_attack_named(gname: String) -> void:
	var slash_w := 11.0
	var slash_len := 88.0
	match gname:
		"Rage Slash":
			slash_w = 14.0
			slash_len = 96.0
		"Shadow Strike":
			slash_w = 9.0
			slash_len = 72.0
	slash_len *= meta_melee_range_mult

	_play_melee_slash_vfx(_gem_projectile_color(gname).lightened(0.22), slash_w, slash_len)

	var reach := _melee_reach()
	var nearest := get_nearest_enemy()
	if not nearest or global_position.distance_to(nearest.global_position) >= reach:
		print("No enemy in melee range")
		return

	var enraged_rage_slash: bool = gname == "Rage Slash" and _rage_haste_time > 0.0
	var dmg_f: float = equipped_gem.damage
	match gname:
		"Holy Shield Bash":
			dmg_f *= 1.12 * guardian_bash_damage_mult
			if nearest.has_method("apply_knockback"):
				nearest.call("apply_knockback", global_position, 240.0 * guardian_knockback_mult)
		"Rage Slash":
			dmg_f *= 1.4
			if enraged_rage_slash:
				dmg_f *= meta_damage_while_rage_mult
			_rage_haste_time = 2.4 * berserker_rage_duration_mult
		"Shadow Strike":
			dmg_f *= 1.62
			_shadow_move_time = 1.25
		_:
			dmg_f *= 1.3

	var raw_m: int = _dmg_scaled(dmg_f)
	nearest.take_damage(_roll_outgoing_damage(raw_m))
	get_tree().call_group("run_arena", "record_skill_damage", gname, raw_m)
	print("Melee hit with ", gname)


func _play_melee_slash_vfx(col: Color, line_width: float = 11.0, reach: float = 88.0) -> void:
	var slash := Line2D.new()
	slash.width = line_width
	slash.default_color = col
	slash.antialiased = true
	slash.z_index = 8
	slash.points = PackedVector2Array([Vector2(12, 0), Vector2(reach, 0)])
	get_parent().add_child(slash)
	slash.global_position = global_position
	slash.global_rotation = $Visual.rotation
	var tw := slash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "width", 1.5, 0.11)
	tw.tween_property(slash, "modulate:a", 0.0, 0.11).from(1.0)
	tw.finished.connect(slash.queue_free)


func heal(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	health = mini(max_health, health + amount)
	_sync_health_bar()
	print("Player healed ", amount, " (HP ", health, "/", max_health, ")")
	if class_passive_paladin_heal_nova_ratio > 0.0:
		var nova_dmg: int = int(round(float(amount) * class_passive_paladin_heal_nova_ratio * meta_holy_damage_mult))
		if nova_dmg > 0:
			_class_passive_paladin_holy_nova(nova_dmg)


func _sync_health_bar() -> void:
	if health_bar:
		health_bar.max_value = float(max_health)
		health_bar.value = float(health)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	if _invulnerability_timer > 0.0:
		print("Player invulnerable — ignored ", amount, " damage")
		return
	var effective_dodge: float = dodge_chance + (0.25 if _smoke_bomb_time > 0.0 else 0.0)
	if effective_dodge > 0.0 and randf() < effective_dodge:
		print("Player dodged an attack!")
		return
	var dmg_mult: float = incoming_damage_multiplier
	if class_passive_guardian_low_hp_dr > 0.0 and max_health > 0:
		var hp_frac := float(health) / float(max_health)
		if hp_frac <= 0.5:
			dmg_mult *= (1.0 - class_passive_guardian_low_hp_dr)
	dmg_mult *= _skill_temp_damage_taken_mult()
	var amt: int = int(round(float(amount) * dmg_mult))
	amt = maxi(0, amt)
	health = maxi(0, health - amt)
	_sync_health_bar()
	print("Player took ", amt, " damage (raw ", amount, "). Health left: ", health)
	if amt > 0 and invuln_seconds_after_hit > 0.0:
		_invulnerability_timer = invuln_seconds_after_hit
	if health <= 0:
		_is_dead = true
		_start_death_sequence()


func _start_death_sequence() -> void:
	pending_level_ups = 0
	set_physics_process(false)
	print("Player defeated — requesting arena.end_run(false)")
	get_tree().call_group("run_arena", "end_run", false)
