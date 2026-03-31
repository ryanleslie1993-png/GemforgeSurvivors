extends RefCounted
## Data-driven POE-like meta trees.
## Per class: 5 major nodes (center + 4 corners), each with 4 small passive connectors.

const KIND_CENTER := "center"
const KIND_PASSIVE := "passive"
const KIND_CORNER := "corner"

static var ALL_TREES: Dictionary = {}
static var _built: bool = false


static func ensure_built() -> void:
	if _built:
		return
	_built = true
	_register_all()


static func _n(id: String, title: String, description: String, kind: String, pos: Vector2, cost: int, prereqs: Array, bonus: Dictionary = {}) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"kind": kind,
		"pos": pos,
		"cost": cost,
		"prereqs": prereqs.duplicate(),
		"bonus": bonus.duplicate(),
	}


static func _register_tree(class_id: String, nodes: Array) -> void:
	ALL_TREES[class_id] = {"class_id": class_id, "nodes": nodes}


static func get_tree(class_id: String) -> Dictionary:
	ensure_built()
	return ALL_TREES.get(class_id, {})


static func get_all_class_ids() -> PackedStringArray:
	ensure_built()
	var k: Array = ALL_TREES.keys()
	k.sort()
	var out := PackedStringArray()
	for x in k:
		out.append(str(x))
	return out


## Human-readable bonus lines for tooltips and the Node Details panel.
static func format_bonus_for_ui(b: Dictionary) -> String:
	if b.is_empty():
		return "—"
	var parts: PackedStringArray = []
	var keys := b.keys()
	keys.sort()
	for k in keys:
		var ks := str(k)
		if ks.begins_with("flag_"):
			parts.append(_format_flag_bonus(ks))
			continue
		var v = b[k]
		var s := _format_stat_bonus(str(ks), v)
		if s != "":
			parts.append(s)
	return ", ".join(parts) if parts.size() > 0 else "—"


static func _format_flag_bonus(flag_key: String) -> String:
	match flag_key:
		"flag_iron_wall":
			return "Unlocks: Iron Wall"
		"flag_taunt":
			return "Unlocks: Taunt Mastery"
		"flag_retribution":
			return "Unlocks: Retribution"
		"flag_angel":
			return "Unlocks: Guardian Angel"
		"flag_blood_frenzy":
			return "Unlocks: Blood Frenzy"
		"flag_charge":
			return "Unlocks: Unstoppable Charge"
		"flag_roar":
			return "Unlocks: Thunderous Roar"
		"flag_last_stand":
			return "Unlocks: Last Stand"
		"flag_frost_nova":
			return "Unlocks: Frost Nova"
		"flag_chain":
			return "Unlocks: Lightning Chain"
		"flag_overload":
			return "Unlocks: Elemental Overload"
		"flag_cataclysm":
			return "Unlocks: Cataclysm"
		"flag_vanish":
			return "Unlocks: Vanish"
		"flag_poison":
			return "Unlocks: Poison Blades"
		"flag_assassinate":
			return "Unlocks: Assassinate"
		"flag_blade_dance":
			return "Unlocks: Blade Dance"
		"flag_bear":
			return "Unlocks: Bear Companion"
		"flag_traps":
			return "Unlocks: Trap Master"
		"flag_precision":
			return "Unlocks: Precision Shot"
		"flag_rain":
			return "Unlocks: Rain of Arrows"
		"flag_consecrated":
			return "Unlocks: Consecrated Ground"
		"flag_hammer":
			return "Unlocks: Divine Hammer"
		"flag_blessing":
			return "Unlocks: Blessing of Light"
		"flag_avenger":
			return "Unlocks: Holy Avenger"
		"flag_bear_form":
			return "Unlocks: Bear Form"
		"flag_wolf_form":
			return "Unlocks: Wolf Form"
		"flag_vine":
			return "Unlocks: Vine Prison"
		"flag_wrath":
			return "Unlocks: Nature's Wrath"
		"flag_skeletons":
			return "Unlocks: Skeleton Army"
		"flag_life_drain":
			return "Unlocks: Life Drain"
		"flag_weakness":
			return "Unlocks: Curse of Weakness"
		"flag_death_nova":
			return "Unlocks: Death Nova"
		_:
			var tail := flag_key.trim_prefix("flag_").replace("_", " ").strip_edges()
			return "Unlocks: %s" % tail.capitalize()


static func _format_stat_bonus(ks: String, v: Variant) -> String:
	match ks:
		"max_health_flat":
			return "+%d Max Health" % int(v)
		"extra_projectiles":
			return "+%d Projectile(s)" % int(v)
		"lifesteal_add":
			return "+%d Life Steal" % int(v)
		"summon_count_add":
			return "+%d Summons" % int(v)
		"pierce_add":
			return "+%d Pierce" % int(v)
		"crit_chance_add", "distant_crit_add":
			return "+%.1f%% Crit Chance" % (float(v) * 100.0)
		"smite_heal_add":
			return "+%.0f Smite Heal" % float(v)
		"dr_mult":
			return "+%.1f%% Damage Reduction" % ((1.0 - float(v)) * 100.0)
		"cdr_mult":
			return "+%.1f%% Cooldown Recovery" % ((1.0 - float(v)) * 100.0)
		"incoming_damage_mult":
			return "+%.1f%% Damage Reduction" % ((1.0 - float(v)) * 100.0)
		"elem_damage_mult":
			return "+%.2f%% Elemental Damage" % ((float(v) - 1.0) * 100.0)
		"holy_damage_mult":
			return "+%.2f%% Holy Damage" % ((float(v) - 1.0) * 100.0)
		"thorn_damage_mult":
			return "+%.2f%% Thorn Damage" % ((float(v) - 1.0) * 100.0)
		"decay_mult":
			return "+%.2f%% Decay Damage" % ((float(v) - 1.0) * 100.0)
		"healing_mult":
			return "+%.2f%% Healing" % ((float(v) - 1.0) * 100.0)
		"nature_heal_mult":
			return "+%.2f%% Nature Healing" % ((float(v) - 1.0) * 100.0)
		"curse_strength_mult":
			return "+%.2f%% Curse Strength" % ((float(v) - 1.0) * 100.0)
		"projectile_speed_mult":
			return "+%.2f%% Projectile Speed" % ((float(v) - 1.0) * 100.0)
		"taunt_duration_mult":
			return "+%.2f%% Taunt Duration" % ((float(v) - 1.0) * 100.0)
		"area_mult":
			return "+%.2f%% Area Size" % ((float(v) - 1.0) * 100.0)
		"slow_strength_mult":
			return "+%.2f%% Slow Potency" % ((float(v) - 1.0) * 100.0)
		"form_duration_mult":
			return "+%.2f%% Form Duration" % ((float(v) - 1.0) * 100.0)
		"burn_duration_mult":
			return "+%.2f%% Burn Duration" % ((float(v) - 1.0) * 100.0)
		"rage_build_mult":
			return "+%.2f%% Rage Build" % ((float(v) - 1.0) * 100.0)
		"damage_while_rage_mult":
			return "+%.2f%% Damage While Raging" % ((float(v) - 1.0) * 100.0)
		"low_hp_move_mult":
			return "+%.2f%% Move Speed (Low HP)" % ((float(v) - 1.0) * 100.0)
		"melee_range_mult":
			return "+%.2f%% Melee Range" % ((float(v) - 1.0) * 100.0)
		"crit_damage_mult":
			return "+%.2f%% Crit Damage" % ((float(v) - 1.0) * 100.0)
		"kill_move_mult":
			return "+%.2f%% Move Speed on Kill" % ((float(v) - 1.0) * 100.0)
		"backstab_mult":
			return "+%.2f%% Backstab Damage" % ((float(v) - 1.0) * 100.0)
		"trap_damage_mult":
			return "+%.2f%% Trap Damage" % ((float(v) - 1.0) * 100.0)
		"companion_hp_mult":
			return "+%.2f%% Companion Health" % ((float(v) - 1.0) * 100.0)
		"kite_move_mult":
			return "+%.2f%% Move Speed" % ((float(v) - 1.0) * 100.0)
		"aura_dr_mult":
			return "+%.2f%% Aura Mitigation" % ((float(v) - 1.0) * 100.0)
		"knockback_mult":
			return "+%.2f%% Knockback" % ((float(v) - 1.0) * 100.0)
		"damage_while_rage":
			return "+%.2f%% Damage While Raging" % ((float(v) - 1.0) * 100.0)
		_:
			return ""


## One line per non-default aggregate value (from MetaProgression.aggregate_bonuses).
static func format_accumulated_stats_lines(agg: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var h: int = int(agg.get("max_health_flat", 0))
	if h != 0:
		out.append("Max Health: +%d" % h)

	var idm: float = float(agg.get("incoming_damage_mult", 1.0))
	if absf(idm - 1.0) > 0.0001:
		out.append("Damage Reduction: +%.1f%%" % ((1.0 - idm) * 100.0))

	_append_mult_line(out, agg, "holy_damage_mult", "Holy Damage")
	_append_mult_line(out, agg, "elem_damage_mult", "Elemental Damage")
	_append_mult_line(out, agg, "thorn_damage_mult", "Thorn Damage")
	_append_mult_line(out, agg, "decay_mult", "Decay Damage")
	_append_mult_line(out, agg, "healing_mult", "Healing")
	_append_mult_line(out, agg, "nature_heal_mult", "Nature Healing")
	var cdr: float = float(agg.get("cdr_mult", 1.0))
	if absf(cdr - 1.0) > 0.0001:
		out.append("Cooldown Recovery: +%.1f%%" % ((1.0 - cdr) * 100.0))
	_append_mult_line(out, agg, "projectile_speed_mult", "Projectile Speed")
	_append_mult_line(out, agg, "kite_move_mult", "Movement Speed")
	_append_mult_line(out, agg, "kill_move_mult", "Movement Speed (on kill)")
	_append_mult_line(out, agg, "low_hp_move_mult", "Movement Speed (low HP)")
	_append_mult_line(out, agg, "crit_damage_mult", "Crit Damage")

	var cca: float = float(agg.get("crit_chance_add", 0.0))
	if absf(cca) > 0.00001:
		out.append("Crit Chance: +%.1f%%" % (cca * 100.0))
	var dca: float = float(agg.get("distant_crit_add", 0.0))
	if absf(dca) > 0.00001:
		out.append("Crit Chance (distant): +%.1f%%" % (dca * 100.0))

	_append_mult_line(out, agg, "area_mult", "Area Size")
	_append_mult_line(out, agg, "taunt_duration_mult", "Taunt Duration")
	_append_mult_line(out, agg, "rage_build_mult", "Rage Build")
	_append_mult_line(out, agg, "damage_while_rage_mult", "Damage While Raging")
	_append_mult_line(out, agg, "backstab_mult", "Backstab Damage")
	_append_mult_line(out, agg, "trap_damage_mult", "Trap Damage")
	_append_mult_line(out, agg, "companion_hp_mult", "Companion Health")
	_append_mult_line(out, agg, "melee_range_mult", "Melee Range")
	_append_mult_line(out, agg, "burn_duration_mult", "Burn Duration")
	_append_mult_line(out, agg, "slow_strength_mult", "Slow Potency")
	_append_mult_line(out, agg, "form_duration_mult", "Form Duration")
	_append_mult_line(out, agg, "curse_strength_mult", "Curse Strength")
	_append_mult_line(out, agg, "aura_dr_mult", "Aura Mitigation")
	_append_mult_line(out, agg, "knockback_mult", "Knockback")

	var ep: int = int(agg.get("extra_projectiles", 0))
	if ep != 0:
		out.append("Extra Projectiles: +%d" % ep)
	var pa: int = int(agg.get("pierce_add", 0))
	if pa != 0:
		out.append("Pierce: +%d" % pa)
	var ls: int = int(agg.get("lifesteal_add", 0))
	if ls != 0:
		out.append("Life Steal: +%d" % ls)
	var sc: int = int(agg.get("summon_count_add", 0))
	if sc != 0:
		out.append("Summon Count: +%d" % sc)

	var sha: float = float(agg.get("smite_heal_add", 0.0))
	if absf(sha) > 0.00001:
		out.append("Smite Heal: +%.0f" % sha)

	return out


static func _append_mult_line(lines: PackedStringArray, agg: Dictionary, key: String, label: String) -> void:
	var m: float = float(agg.get(key, 1.0))
	if absf(m - 1.0) > 0.0001:
		lines.append("%s: +%.1f%%" % [label, (m - 1.0) * 100.0])


static func unlocked_flag_summary_lines(class_id: String) -> PackedStringArray:
	ensure_built()
	var tree: Dictionary = get_tree(class_id)
	var seen: Dictionary = {}
	var out: PackedStringArray = []
	for row in tree.get("nodes", []):
		var nid: String = str(row.get("id", ""))
		if not MetaProgression.is_unlocked(class_id, nid):
			continue
		var b: Dictionary = row.get("bonus", {})
		for k in b.keys():
			var ks: String = str(k)
			if not ks.begins_with("flag_"):
				continue
			if seen.has(ks):
				continue
			seen[ks] = true
			var line: String = _format_flag_bonus(ks)
			line = line.replace("Unlocks: ", "Skill unlock — ")
			out.append(line)
	out.sort()
	return out


static func find_node(class_id: String, node_id: String) -> Dictionary:
	var t: Dictionary = get_tree(class_id)
	for row in t.get("nodes", []):
		if str(row.get("id", "")) == node_id:
			return row
	return {}


static func get_starting_node_id(class_id: String) -> String:
	var t: Dictionary = get_tree(class_id)
	for row in t.get("nodes", []):
		if str(row.get("kind", "")) == KIND_CENTER:
			return str(row.get("id", ""))
	return ""


static func _register_all() -> void:
	_register_from_def(_guardian_def())
	_register_from_def(_berserker_def())
	_register_from_def(_elementalist_def())
	_register_from_def(_assassin_def())
	_register_from_def(_ranger_def())
	_register_from_def(_paladin_def())
	_register_from_def(_druid_def())
	_register_from_def(_necromancer_def())


static func _register_from_def(d: Dictionary) -> void:
	var class_id: String = str(d.get("class_id", ""))
	if class_id == "":
		return
	var nodes: Array = []
	var center_id := "%s_center" % class_id
	nodes.append(_n(center_id, str(d["center"]["title"]), str(d["center"]["desc"]), KIND_CENTER, Vector2(0.5, 0.5), 0, [], d["center"].get("bonus", {})))

	var c_sat_names: Array = d.get("center_satellites", [])
	var c_sat_pos := [Vector2(0.372, 0.372), Vector2(0.628, 0.372), Vector2(0.628, 0.628), Vector2(0.372, 0.628)]
	for i in range(mini(4, c_sat_names.size())):
		var sid := "%s_center_s%d" % [class_id, i + 1]
		var sat_b := _small_bonus_from_name(str(c_sat_names[i]))
		nodes.append(_n(sid, str(c_sat_names[i]), "", KIND_PASSIVE, c_sat_pos[i], 1, [center_id], sat_b))

	var corners: Array = d.get("corners", [])
	for i in range(mini(4, corners.size())):
		var cdef: Dictionary = corners[i]
		var dir: Vector2 = _dir_for_index(i)
		var major_pos: Vector2 = _clamp_to_tree(Vector2(0.5, 0.5) + dir * 0.445)
		var p0: String = center_id
		for j in range(4):
			var sid2 := "%s_b%d_p%d" % [class_id, i + 1, j + 1]
			var t: float = 0.065 + float(j) * 0.092
			var wobble := _perp_for_index(i) * (0.0045 if j % 2 == 0 else -0.0045)
			var spos := _clamp_to_tree(Vector2(0.5, 0.5) + dir * t + wobble)
			var pname := str(cdef.get("passives", ["Passive", "Passive", "Passive", "Passive"])[j])
			var pb := _small_bonus_from_name(pname)
			nodes.append(_n(sid2, pname, "", KIND_PASSIVE, spos, 1, [p0], pb))
			p0 = sid2
		var major_id := "%s_corner_%d" % [class_id, i + 1]
		var maj_bonus: Dictionary = cdef.get("bonus", {})
		var maj_desc := str(cdef.get("desc", "Major class skill unlock."))
		nodes.append(_n(major_id, str(cdef.get("title", "Major Skill")), maj_desc, KIND_CORNER, major_pos, 2, [p0], maj_bonus))

	_register_tree(class_id, nodes)


static func _dir_for_index(i: int) -> Vector2:
	match i:
		0:
			return Vector2(0, -1)
		1:
			return Vector2(1, 0)
		2:
			return Vector2(0, 1)
		_:
			return Vector2(-1, 0)


static func _perp_for_index(i: int) -> Vector2:
	match i:
		0:
			return Vector2(1, 0)
		1:
			return Vector2(0, 1)
		2:
			return Vector2(-1, 0)
		_:
			return Vector2(0, -1)


static func _clamp_to_tree(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.055, 0.945), clampf(p.y, 0.055, 0.945))


static func _small_bonus_from_name(passive_label: String) -> Dictionary:
	var n := passive_label.to_lower()
	if "max health" in n or "vital" in n or "companion health" in n:
		return {"max_health_flat": 12}
	if "holy" in n and "damage" in n:
		return {"holy_damage_mult": 1.015}
	if "nature" in n and ("heal" in n or "damage" in n):
		return {"nature_heal_mult": 1.015} if "heal" in n else {"decay_mult": 1.015}
	if "thorn" in n:
		return {"thorn_damage_mult": 1.015}
	if "slow" in n:
		return {"slow_strength_mult": 1.015}
	if "armor" in n or "iron" in n:
		return {"dr_mult": 0.992}
	if "reduction" in n or "ward" in n or "evasion" in n or "mitigation" in n:
		return {"dr_mult": 0.993}
	if "cooldown" in n:
		return {"cdr_mult": 0.992}
	if "crit chance" in n or ("crit" in n and "damage" not in n):
		return {"crit_chance_add": 0.012}
	if "crit damage" in n:
		return {"crit_damage_mult": 1.018}
	if "elemental" in n or "cold" in n or "shock" in n or "physical" in n:
		return {"elem_damage_mult": 1.015}
	if "poison" in n:
		return {"decay_mult": 1.016}
	if "chain" in n or "pierce" in n:
		return {"pierce_add": 1}
	if "melee" in n or "impact" in n or "counter" in n or "hit damage" in n:
		return {"elem_damage_mult": 1.014}
	if "ranged" in n or "distance" in n:
		return {"distant_crit_add": 0.01}
	if "leech" in n or "life steal" in n:
		return {"lifesteal_add": 2}
	if "heal" in n or "blessing" in n:
		return {"healing_mult": 1.016}
	if "rage" in n:
		return {"rage_build_mult": 1.018}
	if "attack speed" in n or "cast speed" in n or "haste" in n:
		return {"cdr_mult": 0.988}
	if "move speed" in n or "dash" in n or "companion speed" in n:
		return {"kite_move_mult": 1.012}
	if "speed" in n:
		return {"projectile_speed_mult": 1.015}
	if "damage" in n:
		return {"elem_damage_mult": 1.012}
	if "burn" in n or "status" in n or "debuff" in n:
		return {"burn_duration_mult": 1.015}
	if "aoe" in n or "area" in n or "radius" in n or "nova" in n:
		return {"area_mult": 1.012}
	if "projectile" in n or "arrow" in n:
		return {"extra_projectiles": 1}
	if "taunt" in n or "threat" in n:
		return {"taunt_duration_mult": 1.018}
	if "summon" in n or "skeleton" in n or "minion" in n:
		return {"summon_count_add": 1}
	if "curse" in n:
		return {"curse_strength_mult": 1.016}
	if "backstab" in n:
		return {"backstab_mult": 1.018}
	if "trap" in n:
		return {"trap_damage_mult": 1.018}
	if "form" in n or "stealth" in n or "root" in n or "stun" in n:
		return {"form_duration_mult": 1.015}
	if "buff" in n or "aura" in n:
		return {"healing_mult": 1.01}
	return {"area_mult": 1.008}


static func _guardian_def() -> Dictionary:
	return {
		"class_id": "Guardian",
		"center": {"title": "Holy Shield Bash", "desc": "Starting skill: short-range melee knockback.", "bonus": {}},
		"center_satellites": ["+Max Health", "+Armor", "+Block Recovery", "+Taunt Duration"],
		"corners": [
			{"title": "Iron Wall", "desc": "Massive damage reduction aura.", "bonus": {"flag_iron_wall": 1}, "passives": ["+Armor", "+Max Health", "+Ward Strength", "+Aura Radius"]},
			{"title": "Taunt Mastery", "desc": "Enemies are forced to attack you.", "bonus": {"flag_taunt": 1}, "passives": ["+Taunt Duration", "+Threat", "+Move Speed", "+Cooldown Reduction"]},
			{"title": "Retribution", "desc": "Reflect damage when hit.", "bonus": {"flag_retribution": 1}, "passives": ["+Thorns", "+Damage Reduction", "+Counter Damage", "+Shield Size"]},
			{"title": "Guardian Angel", "desc": "Temporary invulnerability for self or ally.", "bonus": {"flag_angel": 1}, "passives": ["+Holy Power", "+Healing", "+Buff Duration", "+Cooldown Reduction"]},
		],
	}


static func _berserker_def() -> Dictionary:
	return {"class_id": "Berserker", "center": {"title": "Rage Slash", "desc": "Starting skill: high-damage melee cleave."}, "center_satellites": ["+Rage Build Rate", "+Cleave Range", "+Crit Chance", "+Low HP Speed"], "corners": [
		{"title": "Blood Frenzy", "desc": "Massive damage boost while low HP.", "bonus": {"flag_blood_frenzy": 1}, "passives": ["+Low HP Damage", "+Rage Gain", "+Attack Speed", "+Leech"]},
		{"title": "Unstoppable Charge", "desc": "Dash that damages in path.", "bonus": {"flag_charge": 1}, "passives": ["+Dash Distance", "+Impact Damage", "+Move Speed", "+Stun Chance"]},
		{"title": "Thunderous Roar", "desc": "AoE stun + damage.", "bonus": {"flag_roar": 1}, "passives": ["+Roar Radius", "+Stun Duration", "+Physical Damage", "+Cooldown Reduction"]},
		{"title": "Last Stand", "desc": "Cheat death burst power.", "bonus": {"flag_last_stand": 1}, "passives": ["+Survival Time", "+Damage while Enraged", "+Damage Reduction", "+Crit Damage"]},
	]}


static func _elementalist_def() -> Dictionary:
	return {"class_id": "Elementalist", "center": {"title": "Fireball", "desc": "Starting skill: ranged projectile + burn."}, "center_satellites": ["+Burn Duration", "+Elemental Damage", "+Projectile Speed", "+Area Size"], "corners": [
		{"title": "Frost Nova", "desc": "AoE slow + damage.", "bonus": {"flag_frost_nova": 1}, "passives": ["+Cold Damage", "+Slow Strength", "+Area Size", "+Cooldown Reduction"]},
		{"title": "Lightning Chain", "desc": "Jumps between enemies.", "bonus": {"flag_chain": 1}, "passives": ["+Chain Count", "+Shock Damage", "+Cast Speed", "+Crit Chance"]},
		{"title": "Elemental Overload", "desc": "All elements gain bonus damage.", "bonus": {"flag_overload": 1}, "passives": ["+Elemental Damage", "+Exposure", "+Cooldown Reduction", "+Status Duration"]},
		{"title": "Cataclysm", "desc": "Big AoE ultimate cycling elements.", "bonus": {"flag_cataclysm": 1}, "passives": ["+Area Size", "+Ultimate Damage", "+Projectile Speed", "+Cooldown Reduction"]},
	]}


static func _assassin_def() -> Dictionary:
	return {"class_id": "Assassin", "center": {"title": "Shadow Strike", "desc": "Starting skill: short-range high burst."}, "center_satellites": ["+Critical Chance", "+Critical Damage", "+Backstab Bonus", "+Cooldown Reduction"], "corners": [
		{"title": "Vanish", "desc": "Brief invisibility + next attack critical.", "bonus": {"flag_vanish": 1}, "passives": ["+Stealth Duration", "+Crit Chance", "+Move Speed", "+Cooldown Reduction"]},
		{"title": "Poison Blades", "desc": "DoT on all attacks.", "bonus": {"flag_poison": 1}, "passives": ["+Poison Damage", "+Poison Duration", "+Attack Speed", "+Backstab Bonus"]},
		{"title": "Assassinate", "desc": "Huge damage on low-HP enemies.", "bonus": {"flag_assassinate": 1}, "passives": ["+Execute Threshold", "+Crit Damage", "+Move Speed on Kill", "+Cooldown Reduction"]},
		{"title": "Blade Dance", "desc": "Multi-hit dash combo.", "bonus": {"flag_blade_dance": 1}, "passives": ["+Dash Count", "+Hit Damage", "+Crit Chance", "+Evasion"]},
	]}


static func _ranger_def() -> Dictionary:
	return {"class_id": "Ranger", "center": {"title": "Arrow Volley", "desc": "Starting skill: multi-arrow ranged attack."}, "center_satellites": ["+Projectile Count", "+Projectile Speed", "+Crit vs Distant", "+Move Speed"], "corners": [
		{"title": "Bear Companion", "desc": "Summons a tanky bear.", "bonus": {"flag_bear": 1}, "passives": ["+Companion Health", "+Companion Damage", "+Taunt Duration", "+Companion Speed"]},
		{"title": "Trap Master", "desc": "Lays slowing/explosive traps.", "bonus": {"flag_traps": 1}, "passives": ["+Trap Damage", "+Trap Arm Speed", "+Slow Strength", "+Trap Radius"]},
		{"title": "Precision Shot", "desc": "High single-target damage.", "bonus": {"flag_precision": 1}, "passives": ["+Crit Chance", "+Crit Damage", "+Distance Damage", "+Projectile Speed"]},
		{"title": "Rain of Arrows", "desc": "Large AoE arrow storm.", "bonus": {"flag_rain": 1}, "passives": ["+Area Size", "+Projectile Count", "+Cooldown Reduction", "+Physical Damage"]},
	]}


static func _paladin_def() -> Dictionary:
	return {"class_id": "Paladin", "center": {"title": "Holy Smite", "desc": "Starting skill: ranged projectile + self heal."}, "center_satellites": ["+Holy Damage", "+Healing", "+Armor", "+Taunt Duration"], "corners": [
		{"title": "Consecrated Ground", "desc": "Healing + damage aura.", "bonus": {"flag_consecrated": 1}, "passives": ["+Aura Radius", "+Holy Damage", "+Healing", "+Damage Reduction"]},
		{"title": "Divine Hammer", "desc": "Powerful melee smash.", "bonus": {"flag_hammer": 1}, "passives": ["+Melee Damage", "+Knockback", "+Armor", "+Cooldown Reduction"]},
		{"title": "Blessing of Light", "desc": "Team-wide heal over time.", "bonus": {"flag_blessing": 1}, "passives": ["+Healing Amount", "+Buff Duration", "+Cooldown Reduction", "+Holy Damage"]},
		{"title": "Holy Avenger", "desc": "Temporary massive damage + healing boost.", "bonus": {"flag_avenger": 1}, "passives": ["+Burst Damage", "+Healing", "+Crit Chance", "+Aura Strength"]},
	]}


static func _druid_def() -> Dictionary:
	return {"class_id": "Druid", "center": {"title": "Thorn Burst", "desc": "Starting skill: ground AoE + slow."}, "center_satellites": ["+Thorn Damage", "+Slow Strength", "+AoE Size", "+Nature Healing"], "corners": [
		{"title": "Bear Form", "desc": "Temporary tank form.", "bonus": {"flag_bear_form": 1}, "passives": ["+Form Duration", "+Armor", "+Max Health", "+Damage Reduction"]},
		{"title": "Wolf Form", "desc": "Temporary high speed + damage form.", "bonus": {"flag_wolf_form": 1}, "passives": ["+Move Speed", "+Attack Speed", "+Crit Chance", "+Form Duration"]},
		{"title": "Vine Prison", "desc": "Root enemies in place.", "bonus": {"flag_vine": 1}, "passives": ["+Root Duration", "+Area Size", "+Cooldown Reduction", "+Nature Damage"]},
		{"title": "Nature's Wrath", "desc": "Big nature AoE ultimate.", "bonus": {"flag_wrath": 1}, "passives": ["+Ultimate Damage", "+Area Size", "+Cooldown Reduction", "+Nature Healing"]},
	]}


static func _necromancer_def() -> Dictionary:
	return {"class_id": "Necromancer", "center": {"title": "Bone Spear", "desc": "Starting skill: piercing ranged projectile."}, "center_satellites": ["+Pierce Count", "+Life Steal", "+Curse Strength", "+Decay Damage"], "corners": [
		{"title": "Skeleton Army", "desc": "Summon multiple skeletons.", "bonus": {"flag_skeletons": 1}, "passives": ["+Summon Count", "+Minion Damage", "+Minion Health", "+Summon Duration"]},
		{"title": "Life Drain", "desc": "Steal health from enemies.", "bonus": {"flag_life_drain": 1}, "passives": ["+Life Steal", "+Channel Speed", "+Curse Strength", "+Decay Damage"]},
		{"title": "Curse of Weakness", "desc": "Debuff enemies.", "bonus": {"flag_weakness": 1}, "passives": ["+Curse Radius", "+Curse Strength", "+Debuff Duration", "+Cooldown Reduction"]},
		{"title": "Death Nova", "desc": "Explosion when enemy dies.", "bonus": {"flag_death_nova": 1}, "passives": ["+Nova Radius", "+Decay Damage", "+Chain Explosions", "+Pierce Count"]},
	]}
