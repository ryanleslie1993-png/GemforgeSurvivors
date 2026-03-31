extends Node
## Permanent meta progression: skill points per class, unlocked tree nodes, per-class meta XP, save/load.

const SAVE_PATH := "user://meta_progression.json"

const DEFAULT_POINTS_PER_CLASS := 12

var meta_points: Dictionary = {} # class_id -> int
var unlocked_nodes: Dictionary = {} # class_id -> Array[String]
## Per-class meta XP tier (level + exp toward next). Legacy global meta_exp/meta_level migrated on first load.
var class_meta_level: Dictionary = {} # class_id -> int
var class_meta_exp: Dictionary = {} # class_id -> int (progress within current level)

const Catalog = preload("res://scripts/meta/meta_skill_tree_catalog.gd")


func _ready() -> void:
	_load_save()
	_ensure_all_classes()
	print("MetaProgression ready (loaded meta save if present)")


func _ensure_all_classes() -> void:
	Catalog.ensure_built()
	var changed := false
	for class_id in Catalog.get_all_class_ids():
		if not meta_points.has(class_id):
			meta_points[class_id] = DEFAULT_POINTS_PER_CLASS
			changed = true
		if not unlocked_nodes.has(class_id):
			unlocked_nodes[class_id] = []
			changed = true
		var start_id: String = Catalog.get_starting_node_id(class_id)
		if start_id != "" and not start_id in unlocked_nodes[class_id]:
			unlocked_nodes[class_id].append(start_id)
			changed = true
		_ensure_class_meta(class_id)
	if changed:
		save_progress()


func _ensure_class_meta(class_id: String) -> void:
	if class_id == "":
		return
	if not class_meta_level.has(class_id):
		class_meta_level[class_id] = 1
		class_meta_exp[class_id] = 0


func get_points(class_id: String) -> int:
	return int(meta_points.get(class_id, DEFAULT_POINTS_PER_CLASS))


func add_points(class_id: String, amount: int) -> void:
	if amount <= 0:
		return
	meta_points[class_id] = get_points(class_id) + amount
	save_progress()
	print("Meta: +", amount, " points for ", class_id)


func _exp_to_next_for_level(level: int) -> int:
	return 120 + (level - 1) * 45


## Adds meta XP for the class that played the run; levels up and saves immediately.
func add_meta_xp(class_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if class_id == "":
		push_warning("MetaProgression.add_meta_xp: empty class_id — XP not applied (amount was %d)" % amount)
		return
	_ensure_class_meta(class_id)
	var lv: int = int(class_meta_level[class_id])
	var ex: int = int(class_meta_exp[class_id])
	ex += amount
	var next_need: int = _exp_to_next_for_level(lv)
	while ex >= next_need:
		ex -= next_need
		lv += 1
		next_need = _exp_to_next_for_level(lv)
		class_meta_level[class_id] = lv
		class_meta_exp[class_id] = ex
		print("Meta level up: ", class_id, " is now level ", lv)
		save_progress()
	class_meta_level[class_id] = lv
	class_meta_exp[class_id] = ex
	print("Meta EXP gained: ", amount, " for class ", class_id, " → Lv ", lv, " (", ex, "/", next_need, ")")
	save_progress()


## Per-class meta bar data for UI (Character Select, end screen, meta tree).
func get_meta_level_data_for_class(class_id: String) -> Dictionary:
	_ensure_class_meta(class_id)
	var lv: int = int(class_meta_level[class_id])
	var ex: int = int(class_meta_exp[class_id])
	var nxt: int = _exp_to_next_for_level(lv)
	return {"level": lv, "exp": ex, "next": nxt}


func get_unlocked_list(class_id: String) -> Array[String]:
	var a: Variant = unlocked_nodes.get(class_id, [])
	var out: Array[String] = []
	for x in a:
		out.append(str(x))
	return out


func is_unlocked(class_id: String, node_id: String) -> bool:
	return node_id in get_unlocked_list(class_id)


func can_unlock(class_id: String, node_id: String) -> bool:
	if is_unlocked(class_id, node_id):
		return false
	var row: Dictionary = Catalog.find_node(class_id, node_id)
	if row.is_empty():
		return false
	var cost: int = int(row.get("cost", 99))
	if get_points(class_id) < cost:
		return false
	for p in row.get("prereqs", []):
		if not is_unlocked(class_id, str(p)):
			return false
	return true


func unlock_node(class_id: String, node_id: String) -> bool:
	if not can_unlock(class_id, node_id):
		return false
	var row: Dictionary = Catalog.find_node(class_id, node_id)
	var cost: int = int(row.get("cost", 0))
	meta_points[class_id] = get_points(class_id) - cost
	var lst: Array = unlocked_nodes.get(class_id, [])
	lst.append(node_id)
	unlocked_nodes[class_id] = lst
	save_progress()
	print("Meta unlock: ", class_id, " → ", node_id, " (cost ", cost, ", points left ", get_points(class_id), ")")
	return true


func reset_class_tree(class_id: String) -> void:
	var tree: Dictionary = Catalog.get_tree(class_id)
	if tree.is_empty():
		return
	var current_unlocked := get_unlocked_list(class_id)
	var refunded: int = 0
	var keep: Array[String] = []
	var start_id := Catalog.get_starting_node_id(class_id)
	for row in tree.get("nodes", []):
		var nid := str(row.get("id", ""))
		if nid in current_unlocked:
			if nid == start_id:
				keep.append(nid)
			else:
				refunded += int(row.get("cost", 0))
	meta_points[class_id] = get_points(class_id) + refunded
	unlocked_nodes[class_id] = keep
	save_progress()
	print("Meta reset: ", class_id, " refunded ", refunded, " points")


func aggregate_bonuses(class_id: String) -> Dictionary:
	var unlocked := get_unlocked_list(class_id)
	var agg: Dictionary = {
		"max_health_flat": 0,
		"incoming_damage_mult": 1.0,
		"knockback_mult": 1.0,
		"taunt_duration_mult": 1.0,
		"area_mult": 1.0,
		"rage_build_mult": 1.0,
		"damage_while_rage_mult": 1.0,
		"low_hp_move_mult": 1.0,
		"melee_range_mult": 1.0,
		"burn_duration_mult": 1.0,
		"elem_damage_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"cdr_mult": 1.0,
		"crit_chance_add": 0.0,
		"crit_damage_mult": 1.0,
		"kill_move_mult": 1.0,
		"backstab_mult": 1.0,
		"extra_projectiles": 0,
		"trap_damage_mult": 1.0,
		"companion_hp_mult": 1.0,
		"kite_move_mult": 1.0,
		"distant_crit_add": 0.0,
		"healing_mult": 1.0,
		"holy_damage_mult": 1.0,
		"aura_dr_mult": 1.0,
		"smite_heal_add": 0.0,
		"slow_strength_mult": 1.0,
		"form_duration_mult": 1.0,
		"nature_heal_mult": 1.0,
		"thorn_damage_mult": 1.0,
		"lifesteal_add": 0,
		"summon_count_add": 0,
		"curse_strength_mult": 1.0,
		"pierce_add": 0,
		"decay_mult": 1.0,
	}
	var tree: Dictionary = Catalog.get_tree(class_id)
	for row in tree.get("nodes", []):
		var nid: String = str(row.get("id", ""))
		if nid not in unlocked:
			continue
		_accumulate_bonus_dict(agg, row.get("bonus", {}))
	return agg


func _accumulate_bonus_dict(agg: Dictionary, b: Dictionary) -> void:
	for k in b.keys():
		var ks := str(k)
		if ks.begins_with("flag_"):
			continue
		var v = b[k]
		match ks:
			"dr_mult":
				agg["incoming_damage_mult"] = float(agg["incoming_damage_mult"]) * float(v)
			"damage_while_rage":
				agg["damage_while_rage_mult"] = float(agg["damage_while_rage_mult"]) * float(v)
			"max_health_flat", "extra_projectiles", "lifesteal_add", "summon_count_add", "pierce_add":
				agg[ks] = int(agg.get(ks, 0)) + int(v)
			"crit_chance_add", "distant_crit_add", "smite_heal_add":
				agg[ks] = float(agg.get(ks, 0.0)) + float(v)
			"incoming_damage_mult", "knockback_mult", "taunt_duration_mult", "area_mult", "rage_build_mult", "damage_while_rage_mult", "low_hp_move_mult", "melee_range_mult", "burn_duration_mult", "elem_damage_mult", "projectile_speed_mult", "cdr_mult", "crit_damage_mult", "kill_move_mult", "backstab_mult", "trap_damage_mult", "companion_hp_mult", "kite_move_mult", "healing_mult", "holy_damage_mult", "aura_dr_mult", "slow_strength_mult", "form_duration_mult", "nature_heal_mult", "thorn_damage_mult", "curse_strength_mult", "decay_mult":
				agg[ks] = float(agg.get(ks, 1.0)) * float(v)
			_:
				pass


func save_progress() -> void:
	var data: Dictionary = {
		"meta_points": meta_points.duplicate(),
		"unlocked_nodes": {},
		"class_meta_level": {},
		"class_meta_exp": {},
	}
	for k in unlocked_nodes.keys():
		data["unlocked_nodes"][k] = unlocked_nodes[k].duplicate()
	for k in class_meta_level.keys():
		data["class_meta_level"][k] = class_meta_level[k]
	for k in class_meta_exp.keys():
		data["class_meta_exp"][k] = class_meta_exp[k]
	var json_string := JSON.stringify(data)
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("MetaProgression: Failed to save.")
		return
	f.store_string(json_string)
	f.close()
	print("Meta progress saved.")


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Starting fresh.")
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		print("Failed to open save file.")
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Save file is corrupted.")
		return
	var d: Dictionary = parsed
	meta_points = {}
	if d.has("meta_points"):
		for k in d["meta_points"]:
			meta_points[str(k)] = int(d["meta_points"][k])
	unlocked_nodes = {}
	if d.has("unlocked_nodes"):
		for k in d["unlocked_nodes"]:
			var arr: Array = d["unlocked_nodes"][k]
			unlocked_nodes[str(k)] = arr.duplicate()
	class_meta_level.clear()
	class_meta_exp.clear()
	Catalog.ensure_built()
	if d.has("class_meta_level") and d.has("class_meta_exp"):
		for k in d["class_meta_level"]:
			class_meta_level[str(k)] = int(d["class_meta_level"][k])
		for k in d["class_meta_exp"]:
			class_meta_exp[str(k)] = int(d["class_meta_exp"][k])
	elif d.has("meta_level") or d.has("meta_exp"):
		var leg_l: int = int(d.get("meta_level", 1))
		var leg_e: int = int(d.get("meta_exp", 0))
		print("MetaProgression: migrating legacy account meta (Lv ", leg_l, ", ", leg_e, " XP) to all classes")
		for cid in Catalog.get_all_class_ids():
			class_meta_level[cid] = leg_l
			class_meta_exp[cid] = leg_e
	print("Meta progress loaded successfully.")
