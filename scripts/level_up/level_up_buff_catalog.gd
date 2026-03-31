extends RefCounted
## Full level-up pool: 60% / 30% / 10% rarity per slot, 3–4 unique offers.
## Rows may set class_id (StringName) — only that class can roll them; they use lower weight (slightly rarer).

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_EPIC := "epic"
const CLASS_BUFF_WEIGHT := 0.34

## Add rows here — keys: id, rarity, title, description, optional class_id (StringName).
static var BUFF_ROWS: Array[Dictionary] = []

static var _by_id: Dictionary = {}
static var _ids_by_rarity: Dictionary = {}
static var _built: bool = false


static func _build_rows() -> void:
	if _built:
		return
	_built = true
	var _any := StringName()

	BUFF_ROWS = [
		# —— Offensive ——
		{"id": "o_c_dmg_20", "rarity": RARITY_COMMON, "title": "+20% Damage", "description": "All damage you deal is increased.", "class_id": _any},
		{"id": "o_c_aspd_15", "rarity": RARITY_COMMON, "title": "+15% Attack Speed", "description": "Auto-attacks tick down faster.", "class_id": _any},
		{"id": "o_c_pspd_25", "rarity": RARITY_COMMON, "title": "+25% Projectile Speed", "description": "Projectiles move quicker.", "class_id": _any},
		{"id": "o_c_crit_30", "rarity": RARITY_COMMON, "title": "+30% Critical Chance", "description": "More attacks become critical hits.", "class_id": _any},
		{"id": "o_u_dmg_35", "rarity": RARITY_UNCOMMON, "title": "+35% Damage", "description": "Strong offensive scaling.", "class_id": _any},
		{"id": "o_u_aspd_25", "rarity": RARITY_UNCOMMON, "title": "+25% Attack Speed", "description": "Much faster attack cadence.", "class_id": _any},
		{"id": "o_u_proj_1", "rarity": RARITY_UNCOMMON, "title": "+1 Projectile", "description": "Multi-shot: +1 parallel projectile.", "class_id": _any},
		{"id": "o_u_crit_dmg_50", "rarity": RARITY_UNCOMMON, "title": "+50% Critical Damage", "description": "Crits deal much more damage.", "class_id": _any},
		{"id": "o_e_dmg_50", "rarity": RARITY_EPIC, "title": "+50% Damage", "description": "Major damage spike.", "class_id": _any},
		{"id": "o_e_aspd_40", "rarity": RARITY_EPIC, "title": "+40% Attack Speed", "description": "Very high attack tempo.", "class_id": _any},
		{"id": "o_e_proj_2", "rarity": RARITY_EPIC, "title": "+2 Projectiles", "description": "Two extra parallel projectiles.", "class_id": _any},
		{"id": "o_e_double_3", "rarity": RARITY_EPIC, "title": "Double Damage (3 attacks)", "description": "Next 3 attack rounds deal double damage.", "class_id": _any},
		# —— Defensive ——
		{"id": "d_c_hp_40", "rarity": RARITY_COMMON, "title": "+40 Max Health", "description": "Flat max HP; heals you for the same.", "class_id": _any},
		{"id": "d_c_hp_pct_25", "rarity": RARITY_COMMON, "title": "+25% Max Health", "description": "Scales current max HP higher.", "class_id": _any},
		{"id": "d_c_move_15", "rarity": RARITY_COMMON, "title": "+15% Movement Speed", "description": "Kite enemies more easily.", "class_id": _any},
		{"id": "d_c_dr_20", "rarity": RARITY_COMMON, "title": "+20% Damage Reduction", "description": "Take less damage from hits.", "class_id": _any},
		{"id": "d_u_hp_80", "rarity": RARITY_UNCOMMON, "title": "+80 Max Health", "description": "Large flat HP buffer.", "class_id": _any},
		{"id": "d_u_hp_pct_35", "rarity": RARITY_UNCOMMON, "title": "+35% Max Health", "description": "Big percent max HP increase.", "class_id": _any},
		{"id": "d_u_move_25", "rarity": RARITY_UNCOMMON, "title": "+25% Movement Speed", "description": "Much faster repositioning.", "class_id": _any},
		{"id": "d_u_dr_30", "rarity": RARITY_UNCOMMON, "title": "+30% Damage Reduction", "description": "Significantly tougher.", "class_id": _any},
		{"id": "d_u_dodge_15", "rarity": RARITY_UNCOMMON, "title": "+15% Dodge Chance", "description": "Chance to ignore a hit entirely.", "class_id": _any},
		{"id": "d_e_hp_120", "rarity": RARITY_EPIC, "title": "+120 Max Health", "description": "Huge survivability.", "class_id": _any},
		{"id": "d_e_hp_pct_50", "rarity": RARITY_EPIC, "title": "+50% Max Health", "description": "Massive max HP scaling.", "class_id": _any},
		{"id": "d_e_move_40", "rarity": RARITY_EPIC, "title": "+40% Movement Speed", "description": "Blazing move speed.", "class_id": _any},
		{"id": "d_e_dr_40", "rarity": RARITY_EPIC, "title": "+40% Damage Reduction", "description": "Heavily reduced incoming damage.", "class_id": _any},
		{"id": "d_e_invuln_3", "rarity": RARITY_EPIC, "title": "Temporary Invulnerability", "description": "3s invuln after taking damage (stacks duration feel).", "class_id": _any},
		# —— Utility / Special ——
		{"id": "s_c_xp_30", "rarity": RARITY_COMMON, "title": "+30% XP Gain", "description": "Level up faster this run.", "class_id": _any},
		{"id": "s_c_pickup_40", "rarity": RARITY_COMMON, "title": "+40% Pickup Radius", "description": "Magnet XP orbs from farther away.", "class_id": _any},
		{"id": "s_c_area_20", "rarity": RARITY_COMMON, "title": "+20% Area Size", "description": "Larger AoE skills.", "class_id": _any},
		{"id": "s_c_regen_15", "rarity": RARITY_COMMON, "title": "+15% Health Regeneration", "description": "Slow passive healing over time.", "class_id": _any},
		{"id": "s_u_xp_50", "rarity": RARITY_UNCOMMON, "title": "+50% XP Gain", "description": "Much faster XP scaling.", "class_id": _any},
		{"id": "s_u_pickup_80", "rarity": RARITY_UNCOMMON, "title": "+80% Pickup Radius", "description": "Stronger orb magnet.", "class_id": _any},
		{"id": "s_u_area_35", "rarity": RARITY_UNCOMMON, "title": "+35% Area Size", "description": "Noticeably bigger AoEs.", "class_id": _any},
		{"id": "s_u_regen_25", "rarity": RARITY_UNCOMMON, "title": "+25% Health Regeneration", "description": "Faster out-of-combat recovery.", "class_id": _any},
		{"id": "s_e_xp_80", "rarity": RARITY_EPIC, "title": "+80% XP Gain", "description": "Snowball levels extremely fast.", "class_id": _any},
		{"id": "s_e_pickup_150", "rarity": RARITY_EPIC, "title": "+150% Pickup Radius", "description": "Vacuum orbs from huge range.", "class_id": _any},
		{"id": "s_e_area_60", "rarity": RARITY_EPIC, "title": "+60% Area Size", "description": "Screen-filling AoE potential.", "class_id": _any},
		{"id": "s_e_full_heal_max", "rarity": RARITY_EPIC, "title": "Full Heal +20% Max HP", "description": "Top off and raise your cap.", "class_id": _any},
		{"id": "s_e_cdr_30", "rarity": RARITY_EPIC, "title": "Cooldown Surge (30s)", "description": "All skill cooldowns −40% for 30 seconds.", "class_id": _any},
	]


static func _ensure_index() -> void:
	_build_rows()
	# Rebuild if catalog changed (e.g. editor reload) — avoids stale ids.
	if _by_id.size() == BUFF_ROWS.size():
		return
	_by_id.clear()
	_ids_by_rarity.clear()
	_ids_by_rarity[RARITY_COMMON] = []
	_ids_by_rarity[RARITY_UNCOMMON] = []
	_ids_by_rarity[RARITY_EPIC] = []
	for row in BUFF_ROWS:
		var bid: String = row["id"]
		_by_id[bid] = row
		var r: String = row["rarity"]
		_ids_by_rarity[r].append(bid)


static func roll_rarity() -> String:
	var r := randf()
	if r < 0.6:
		return RARITY_COMMON
	if r < 0.9:
		return RARITY_UNCOMMON
	return RARITY_EPIC


static func _player_class_id() -> StringName:
	if GameManager.current_class:
		return StringName(GameManager.current_class.character_class_name)
	return StringName()


static func _row_eligible(row: Dictionary) -> bool:
	var cid: StringName = row.get("class_id", StringName())
	if cid == StringName():
		return true
	return cid == _player_class_id()


static func _row_weight(row: Dictionary) -> float:
	var cid: StringName = row.get("class_id", StringName())
	if cid != StringName():
		return CLASS_BUFF_WEIGHT
	return 1.0


static func _pick_weighted(candidates: Array[Dictionary]) -> Dictionary:
	var total: float = 0.0
	for c in candidates:
		total += _row_weight(c)
	if total <= 0.0:
		return candidates[0]
	var pick := randf() * total
	var acc: float = 0.0
	for c in candidates:
		acc += _row_weight(c)
		if pick <= acc:
			return c
	return candidates[candidates.size() - 1]


static func get_row(buff_id: String) -> Dictionary:
	_ensure_index()
	return _by_id.get(buff_id, {})


static func _gather_for_rarity(rarity: String, chosen: Array[String]) -> Array[Dictionary]:
	_ensure_index()
	var out: Array[Dictionary] = []
	for bid in _ids_by_rarity.get(rarity, []):
		if bid in chosen:
			continue
		var row: Dictionary = _by_id[bid]
		if not _row_eligible(row):
			continue
		out.append(row)
	return out


static func _gather_any_unused(chosen: Array[String]) -> Array[Dictionary]:
	_ensure_index()
	var out: Array[Dictionary] = []
	for row in BUFF_ROWS:
		var bid: String = row["id"]
		if bid in chosen:
			continue
		if not _row_eligible(row):
			continue
		out.append(row)
	return out


## Returns 3–4 choices: { id, title, description, rarity }
static func roll_choices(count: int = -1) -> Array[Dictionary]:
	_ensure_index()
	if count < 0:
		count = randi_range(3, 4)
	var chosen: Array[String] = []
	var out: Array[Dictionary] = []
	for _i in count:
		var rarity := roll_rarity()
		var candidates: Array[Dictionary] = _gather_for_rarity(rarity, chosen)
		if candidates.is_empty():
			candidates = _gather_any_unused(chosen)
		if candidates.is_empty():
			break
		var pick: Dictionary = _pick_weighted(candidates)
		var bid: String = pick["id"]
		chosen.append(bid)
		out.append({
			"id": bid,
			"title": pick["title"],
			"description": pick["description"],
			"rarity": pick["rarity"],
		})
	return out


static func rarity_font_color(rarity: String) -> Color:
	match rarity:
		RARITY_UNCOMMON:
			return Color(0.5, 0.78, 1.0)
		RARITY_EPIC:
			return Color(0.92, 0.62, 1.0)
		_:
			return Color(0.98, 0.98, 1.0)


static func rarity_border_color(rarity: String) -> Color:
	match rarity:
		RARITY_UNCOMMON:
			return Color(0.25, 0.48, 0.92)
		RARITY_EPIC:
			return Color(1.0, 0.8, 0.35)
		_:
			return Color(0.78, 0.8, 0.85)
