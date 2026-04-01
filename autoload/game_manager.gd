extends Node

# Global run state: current class, whether a run is active, and run timer (wire up later).

signal run_started
signal run_ended(success: bool)
signal meta_xp_gained(amount: int)

# Holds the ClassData resource the player picked for this run (inspector / menu will set later).
var current_class: ClassData
var is_in_run: bool = false
var run_time: float = 0.0
var _next_run_is_new: bool = false

const EQUIP_SAVE_PATH := "user://equipment_state.json"
const SLOT_TYPES := ["weapon", "armor", "boots", "accessory"]
const ARCHETYPE_HEAVY := "Heavy"
const ARCHETYPE_LIGHT := "Light"
const ARCHETYPE_ARCANE := "Arcane"
const LEVEL_UP_BUFF_CATALOG = preload("res://scripts/level_up/level_up_buff_catalog.gd")
const CLASS_PASSIVE_BLURBS: Dictionary = {
	"Paladin": "Radiance - 5% of all healing becomes AoE holy damage (scales with meta holy damage).",
	"Guardian": "Bulwark - below 50% HP, take 12% less damage from hits.",
	"Berserker": "Blood Fury - below 50% HP, deal 15% more damage.",
	"Elementalist": "Wildfire - burn damage over time is 12% stronger.",
	"Assassin": "Predator's Eye - +10% critical strike chance.",
	"Ranger": "Strider - +12% movement speed.",
	"Druid": "Verdant Heart - +0.35% max HP regeneration per second.",
	"Necromancer": "Grave Momentum - +10% projectile speed.",
}
const ALL_STARTING_SKILLS: PackedStringArray = [
	"Holy Shield Bash",
	"Rage Slash",
	"Fireball",
	"Shadow Strike",
	"Arrow Volley",
	"Holy Smite",
	"Thorn Burst",
	"Bone Spear",
]

# Per-class equipment state.
var equipped_by_class: Dictionary = {} # class_id -> {slot_type: item_dict}
var inventory_by_class: Dictionary = {} # class_id -> Array[item_dict]
var blank_gems_by_class: Dictionary = {} # class_id -> int
var loose_skill_gems_by_class: Dictionary = {} # class_id -> Array[String]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_load_equipment_state()
	print("GameManager autoload ready")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		generate_full_design_status_report()
		get_viewport().set_input_as_handled()


func _class_key_or_default(class_key: String) -> String:
	return class_key if class_key != "" else "Guardian"


func get_current_class_key() -> String:
	if current_class and current_class.character_class_name != "":
		return str(current_class.character_class_name)
	return "Guardian"


func get_archetype_for_class(class_key: String) -> String:
	var key := _class_key_or_default(class_key)
	match key:
		"Guardian", "Berserker", "Paladin":
			return ARCHETYPE_HEAVY
		"Assassin", "Ranger":
			return ARCHETYPE_LIGHT
		"Elementalist", "Druid", "Necromancer":
			return ARCHETYPE_ARCANE
		_:
			return ARCHETYPE_HEAVY


func _starting_skill_for_class(class_key: String) -> String:
	var key := _class_key_or_default(class_key)
	match key:
		"Guardian":
			return "Holy Shield Bash"
		"Berserker":
			return "Rage Slash"
		"Elementalist":
			return "Fireball"
		"Assassin":
			return "Shadow Strike"
		"Ranger":
			return "Arrow Volley"
		"Paladin":
			return "Holy Smite"
		"Druid":
			return "Thorn Burst"
		"Necromancer":
			return "Bone Spear"
		_:
			return "Basic Attack"


func _starting_weapon_name_for_class(class_key: String) -> String:
	var key := _class_key_or_default(class_key)
	match key:
		"Guardian":
			return "Guardian's Hammer"
		"Berserker":
			return "Iron Greatsword"
		"Paladin":
			return "Blessed Warhammer"
		"Assassin":
			return "Sharp Dagger"
		"Ranger":
			return "Hunter's Bow"
		"Elementalist":
			return "Old Wand"
		"Druid":
			return "Druidic Staff"
		"Necromancer":
			return "Necromancer's Scepter"
		_:
			return "Rusty Blade"


func _starting_weapon_stats_for_archetype(archetype: String) -> Dictionary:
	match archetype:
		ARCHETYPE_HEAVY:
			return {"damage_flat": 14, "armor_flat": 2}
		ARCHETYPE_LIGHT:
			return {"attack_speed_pct": 0.08, "move_speed_flat": 4}
		ARCHETYPE_ARCANE:
			return {"skill_damage_pct": 0.10, "cdr_pct": 0.05}
		_:
			return {"damage_flat": 10}


func mark_next_run_as_new() -> void:
	_next_run_is_new = true


func consume_next_run_is_new() -> bool:
	var value: bool = _next_run_is_new
	_next_run_is_new = false
	return value


func give_starting_weapon_if_needed(class_key: String, is_new_run: bool) -> void:
	var key := _class_key_or_default(class_key)
	if not is_new_run:
		print("Starter weapon check skipped: is_new_run=false for class ", key)
		return
	_ensure_class_state(key)
	var equip: Dictionary = equipped_by_class[key]
	var existing_weapon: Dictionary = equip.get("weapon", {})
	if not existing_weapon.is_empty():
		print("Starter weapon not granted: weapon already equipped for class ", key, " -> ", existing_weapon.get("item_name", "(unknown)"))
		return

	var archetype: String = get_archetype_for_class(key)
	var rarity := "normal"
	var starting_skill: String = _starting_skill_for_class(key)
	var starting_weapon_name: String = _starting_weapon_name_for_class(key)
	var starter_weapon: Dictionary = {
		"item_name": starting_weapon_name,
		"slot_type": "weapon",
		"gear_type": "Weapon",
		"rarity": rarity,
		"archetype": archetype,
		"core_bonus": _core_bonus_for_item("weapon", archetype, rarity),
		"stats": _starting_weapon_stats_for_archetype(archetype),
		"socket_count": 1,
		"socketed_skill": starting_skill,
	}
	equip["weapon"] = starter_weapon
	equipped_by_class[key] = equip
	save_equipment_state()
	print(
		"Gave starter weapon to ",
		key,
		": ",
		starting_weapon_name,
		" [Weapon / ",
		archetype,
		"] | socketed gem: ",
		starting_skill
	)


func get_armor_type_for_class(class_key: String) -> String:
	# Backward-compatible wrapper used by older UI code.
	return get_archetype_for_class(class_key)


func _core_bonus_for_item(slot_type: String, archetype: String, rarity: String) -> Dictionary:
	var scale: float = 1.0
	if rarity == "rare":
		scale = 1.18
	elif rarity == "epic":
		scale = 1.36
	if slot_type == "weapon":
		match archetype:
			ARCHETYPE_HEAVY:
				return {"damage_flat": int(round(12.0 * scale))}
			ARCHETYPE_LIGHT:
				return {"attack_speed_pct": 0.10 * scale, "move_speed_pct": 0.06 * scale}
			ARCHETYPE_ARCANE:
				return {"skill_damage_pct": 0.12 * scale, "cdr_pct": 0.08 * scale}
			_:
				return {"damage_flat": int(round(8.0 * scale))}
	match archetype:
		ARCHETYPE_HEAVY:
			return {"dr_pct": 0.15 * scale}
		ARCHETYPE_LIGHT:
			return {"move_speed_pct": 0.12 * scale, "attack_speed_pct": 0.08 * scale}
		ARCHETYPE_ARCANE:
			return {"skill_damage_pct": 0.12 * scale, "cdr_pct": 0.08 * scale}
		_:
			return {}


func get_default_core_bonus_for_class(class_key: String, rarity: String = "normal", slot_type: String = "armor") -> Dictionary:
	var archetype: String = get_archetype_for_class(class_key)
	return _core_bonus_for_item(slot_type, archetype, rarity)


func _ensure_class_state(class_key: String) -> void:
	var key := _class_key_or_default(class_key)
	if not equipped_by_class.has(key):
		equipped_by_class[key] = {"weapon": {}, "armor": {}, "boots": {}, "accessory": {}}
	if not inventory_by_class.has(key):
		inventory_by_class[key] = []
	if not blank_gems_by_class.has(key):
		blank_gems_by_class[key] = 0
	if not loose_skill_gems_by_class.has(key):
		loose_skill_gems_by_class[key] = []
	# Migration/repair pass for older saves.
	var equip: Dictionary = equipped_by_class[key]
	for slot in SLOT_TYPES:
		var item: Dictionary = equip.get(slot, {})
		if not item.is_empty():
			equip[slot] = _normalize_item_dict(item, key, slot)
	equipped_by_class[key] = equip
	var inv: Array = inventory_by_class[key]
	for i in range(inv.size()):
		if typeof(inv[i]) == TYPE_DICTIONARY:
			inv[i] = _normalize_item_dict(inv[i], key, str(inv[i].get("slot_type", "weapon")))
	inventory_by_class[key] = inv


func _normalize_item_dict(item: Dictionary, class_key: String, slot_type_hint: String) -> Dictionary:
	var out: Dictionary = item.duplicate(true)
	var slot_type: String = str(out.get("slot_type", slot_type_hint)).to_lower()
	if slot_type == "":
		slot_type = slot_type_hint
	out["slot_type"] = slot_type
	if not out.has("rarity"):
		out["rarity"] = "normal"
	var rarity: String = str(out.get("rarity", "normal"))
	if rarity == "common":
		rarity = "normal"
	out["rarity"] = rarity
	if not out.has("archetype") or str(out.get("archetype", "")) == "":
		var legacy_armor_type: String = str(out.get("armor_type", ""))
		if legacy_armor_type == "heavy_plate":
			out["archetype"] = ARCHETYPE_HEAVY
		elif legacy_armor_type == "light_leather":
			out["archetype"] = ARCHETYPE_LIGHT
		elif legacy_armor_type == "arcane_robes":
			out["archetype"] = ARCHETYPE_ARCANE
		else:
			out["archetype"] = get_archetype_for_class(class_key)
	if not out.has("gear_type") or str(out.get("gear_type", "")) == "":
		out["gear_type"] = _gear_type_label(slot_type)
	if not out.has("core_bonus") or typeof(out.get("core_bonus")) != TYPE_DICTIONARY:
		out["core_bonus"] = get_default_core_bonus_for_class(class_key, rarity, slot_type)
	if not out.has("stats") or typeof(out.get("stats")) != TYPE_DICTIONARY:
		out["stats"] = _random_secondary_stats_for_slot(slot_type, str(out["archetype"]), rarity)
	out["socket_count"] = 1
	if not out.has("socketed_skill"):
		out["socketed_skill"] = ""
	return out


func get_equipped_map(class_key: String) -> Dictionary:
	_ensure_class_state(class_key)
	return equipped_by_class[_class_key_or_default(class_key)].duplicate(true)


func get_inventory_list(class_key: String) -> Array:
	_ensure_class_state(class_key)
	return (inventory_by_class[_class_key_or_default(class_key)] as Array).duplicate(true)


func get_blank_gem_count(class_key: String) -> int:
	_ensure_class_state(class_key)
	return int(blank_gems_by_class[_class_key_or_default(class_key)])


func get_loose_skill_gems(class_key: String) -> PackedStringArray:
	_ensure_class_state(class_key)
	var out := PackedStringArray()
	for s in loose_skill_gems_by_class[_class_key_or_default(class_key)]:
		out.append(str(s))
	return out


func _gear_type_label(slot_type: String) -> String:
	match slot_type:
		"weapon":
			return "Weapon"
		"armor":
			return "Armor"
		"boots":
			return "Boots"
		"accessory":
			return "Accessory"
		_:
			return "Gear"


func _random_item_name_for_slot(slot_type: String, archetype: String) -> String:
	match slot_type:
		"weapon":
			match archetype:
				ARCHETYPE_HEAVY:
					return ["Heavy Sword", "War Axe", "Maul", "Great Hammer"].pick_random()
				ARCHETYPE_LIGHT:
					return ["Twin Daggers", "Swift Bow", "Shortblade", "Hunting Spear"].pick_random()
				ARCHETYPE_ARCANE:
					return ["Arcane Staff", "Runed Wand", "Totem Rod", "Spirit Scepter"].pick_random()
				_:
					return "Basic Weapon"
		"armor":
			return ["Worn Chestplate", "Chain Tunic", "Hide Vest", "Padded Mail"].pick_random()
		"boots":
			return ["Traveler Boots", "Rough Greaves", "Scout Shoes", "Mudwalkers"].pick_random()
		"accessory":
			return ["Copper Ring", "Bone Charm", "Simple Talisman", "Old Locket"].pick_random()
		_:
			return "Unknown Gear"


func _random_secondary_stats_for_slot(slot_type: String, archetype: String, rarity: String) -> Dictionary:
	# Start with normal only. Rarer quality can add stronger secondaries later.
	var scale: float = 1.0
	if rarity == "rare":
		scale = 1.2
	elif rarity == "epic":
		scale = 1.45
	match slot_type:
		"weapon":
			match archetype:
				ARCHETYPE_HEAVY:
					return {"damage_flat": int(round(float(randi_range(6, 12)) * scale))}
				ARCHETYPE_LIGHT:
					return {"attack_speed_pct": 0.04 * scale, "move_speed_flat": int(round(float(randi_range(2, 5)) * scale))}
				ARCHETYPE_ARCANE:
					return {"skill_damage_pct": 0.05 * scale, "cdr_pct": 0.03 * scale}
				_:
					return {"damage_flat": int(round(float(randi_range(3, 8)) * scale))}
		"armor":
			return {"armor_flat": int(round(float(randi_range(2, 6)) * scale)), "max_health_flat": int(round(float(randi_range(6, 18)) * scale))}
		"boots":
			return {"move_speed_flat": int(round(float(randi_range(6, 16)) * scale))}
		"accessory":
			return {"damage_flat": int(round(float(randi_range(1, 3)) * scale)), "max_health_flat": int(round(float(randi_range(4, 10)) * scale))}
		_:
			return {}


func gamble_gear_for_class(class_key: String, forced_slot: String = "", forced_archetype: String = "") -> Dictionary:
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	var slot_type := forced_slot.to_lower()
	if slot_type == "" or slot_type not in SLOT_TYPES:
		slot_type = String(SLOT_TYPES[randi() % SLOT_TYPES.size()])
	var rarity := "normal"
	var archetype: String = forced_archetype
	if archetype == "":
		archetype = get_archetype_for_class(key)
	var item := {
		"item_name": _random_item_name_for_slot(slot_type, archetype),
		"slot_type": slot_type,
		"gear_type": _gear_type_label(slot_type),
		"rarity": rarity,
		"archetype": archetype,
		"core_bonus": _core_bonus_for_item(slot_type, archetype, rarity),
		"stats": _random_secondary_stats_for_slot(slot_type, archetype, rarity),
		"socket_count": 1,
		"socketed_skill": "",
	}
	var inv: Array = inventory_by_class[key]
	inv.append(item)
	inventory_by_class[key] = inv
	save_equipment_state()
	print("Blacksmith gamble: crafted ", item["item_name"], " [", item["gear_type"], "] (", archetype, ") for class ", key)
	return item


func equip_inventory_item(class_key: String, inventory_index: int) -> bool:
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	var inv: Array = inventory_by_class[key]
	if inventory_index < 0 or inventory_index >= inv.size():
		return false
	var item: Dictionary = inv[inventory_index]
	var slot_type: String = str(item.get("slot_type", ""))
	if slot_type == "" or slot_type not in SLOT_TYPES:
		return false
	var equip: Dictionary = equipped_by_class[key]
	var prev: Dictionary = equip.get(slot_type, {})
	equip[slot_type] = item.duplicate(true)
	inv.remove_at(inventory_index)
	if not prev.is_empty():
		inv.append(prev)
	equipped_by_class[key] = equip
	inventory_by_class[key] = inv
	save_equipment_state()
	print("Equipped item: ", item.get("item_name", "(unknown)"), " to ", slot_type, " for class ", key)
	return true


func unequip_slot_to_inventory(class_key: String, slot_type: String) -> bool:
	var key := _class_key_or_default(class_key)
	var slot := slot_type.to_lower()
	_ensure_class_state(key)
	if slot not in SLOT_TYPES:
		return false
	var equip: Dictionary = equipped_by_class[key]
	var item: Dictionary = equip.get(slot, {})
	if item.is_empty():
		return false
	var inv: Array = inventory_by_class[key]
	inv.append(item.duplicate(true))
	equip[slot] = {}
	equipped_by_class[key] = equip
	inventory_by_class[key] = inv
	save_equipment_state()
	print("Unequipped item: ", item.get("item_name", "(unknown)"), " from ", slot, " for class ", key)
	return true


func add_blank_gems(class_key: String, amount: int) -> void:
	if amount <= 0:
		return
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	blank_gems_by_class[key] = int(blank_gems_by_class[key]) + amount
	save_equipment_state()
	print("Blank gems +", amount, " for class ", key, " (now ", blank_gems_by_class[key], ")")


func infuse_random_unlocked_skill_gem(class_key: String) -> String:
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	if int(blank_gems_by_class[key]) <= 0:
		print("Gemsmith: no blank gems available for ", key)
		return ""
	var options: PackedStringArray = []
	var tree: Dictionary = MetaProgression.Catalog.get_tree(key)
	var unlocked: Array = MetaProgression.get_unlocked_list(key)
	for row in tree.get("nodes", []):
		var kind: String = str(row.get("kind", ""))
		var node_id: String = str(row.get("id", ""))
		if node_id in unlocked and (kind == MetaProgression.Catalog.KIND_CENTER or kind == MetaProgression.Catalog.KIND_CORNER):
			options.append(str(row.get("title", "Skill Gem")))
	var chosen: String = options[randi() % options.size()] if options.size() > 0 else "Basic Skill Gem"
	blank_gems_by_class[key] = int(blank_gems_by_class[key]) - 1
	var loose: Array = loose_skill_gems_by_class[key]
	loose.append(chosen)
	loose_skill_gems_by_class[key] = loose
	save_equipment_state()
	print("Gemsmith: infused blank gem into ", chosen, " for class ", key)
	return chosen


func socket_first_loose_gem_into_slot(class_key: String, slot_type: String) -> bool:
	var key := _class_key_or_default(class_key)
	var slot := slot_type.to_lower()
	_ensure_class_state(key)
	if slot not in SLOT_TYPES:
		return false
	var equip: Dictionary = equipped_by_class[key]
	var item: Dictionary = equip.get(slot, {})
	if item.is_empty():
		print("Socket failed: no equipped item in ", slot)
		return false
	if int(item.get("socket_count", 0)) <= 0:
		print("Socket failed: item has no socket")
		return false
	if str(item.get("socketed_skill", "")) != "":
		print("Socket failed: item already has a gem")
		return false
	var loose: Array = loose_skill_gems_by_class[key]
	if loose.is_empty():
		print("Socket failed: no infused gems available")
		return false
	var gem_name: String = str(loose[0])
	loose.remove_at(0)
	item["socketed_skill"] = gem_name
	equip[slot] = item
	equipped_by_class[key] = equip
	loose_skill_gems_by_class[key] = loose
	save_equipment_state()
	print("Socketed gem ", gem_name, " into ", slot, " for class ", key)
	return true


func get_equipment_stat_totals(class_key: String) -> Dictionary:
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	var totals := {
		"damage_flat": 0,
		"armor_flat": 0,
		"move_speed_flat": 0,
		"max_health_flat": 0,
		"dr_pct": 0.0,
		"move_speed_pct": 0.0,
		"attack_speed_pct": 0.0,
		"skill_damage_pct": 0.0,
		"cdr_pct": 0.0,
	}
	var equip: Dictionary = equipped_by_class[key]
	for slot in SLOT_TYPES:
		var item: Dictionary = equip.get(slot, {})
		if item.is_empty():
			continue
		var stats: Dictionary = item.get("stats", {})
		for k in ["damage_flat", "armor_flat", "move_speed_flat", "max_health_flat"]:
			totals[k] = int(totals[k]) + int(stats.get(k, 0))
		var core: Dictionary = item.get("core_bonus", {})
		for k2 in ["dr_pct", "move_speed_pct", "attack_speed_pct", "skill_damage_pct", "cdr_pct"]:
			totals[k2] = float(totals[k2]) + float(core.get(k2, 0.0))
		for k3 in ["damage_flat", "armor_flat", "move_speed_flat", "max_health_flat"]:
			totals[k3] = int(totals[k3]) + int(core.get(k3, 0))
	return totals


func _skill_name_to_gem(skill_name: String) -> SkillGemResource:
	var gem := SkillGemResource.new()
	gem.gem_name = skill_name
	gem.gem_type = "projectile"
	match skill_name:
		"Holy Shield Bash":
			gem.damage = 25.0
			gem.cooldown = 1.2
		"Rage Slash":
			gem.damage = 35.0
			gem.cooldown = 0.7
		"Fireball":
			gem.damage = 22.0
			gem.cooldown = 0.9
		"Shadow Strike":
			gem.damage = 40.0
			gem.cooldown = 1.1
		"Arrow Volley":
			gem.damage = 20.0
			gem.cooldown = 0.65
		"Holy Smite":
			gem.damage = 28.0
			gem.cooldown = 1.0
		"Thorn Burst":
			gem.damage = 18.0
			gem.cooldown = 1.4
		"Bone Spear":
			gem.damage = 24.0
			gem.cooldown = 0.8
		"Summon Skeletons", "Skeleton Army":
			gem.gem_name = "Summon Skeletons"
			gem.gem_type = "summon"
			gem.damage = 12.0
			gem.cooldown = 6.0
		_:
			gem.damage = 20.0
			gem.cooldown = 1.0
	return gem


func get_equipped_skill_gem_for_class(class_key: String) -> SkillGemResource:
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	var equip: Dictionary = equipped_by_class[key]
	for slot in ["weapon", "armor", "boots", "accessory"]:
		var item: Dictionary = equip.get(slot, {})
		if item.is_empty():
			continue
		var skill_name: String = str(item.get("socketed_skill", ""))
		if skill_name != "":
			return _skill_name_to_gem(skill_name)
	return null


func generate_full_design_status_report() -> void:
	# Ensure static catalogs are built before reading raw rows.
	LEVEL_UP_BUFF_CATALOG.roll_choices(1)
	MetaProgression.Catalog.ensure_built()

	var lines: PackedStringArray = []
	lines.append("Gemforge Survivors - Full Design Status")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system())
	lines.append("")

	_append_characters_overview(lines)
	_append_skills_overview(lines)
	_append_level_up_catalog(lines)
	_append_gear_system(lines)
	_append_current_run_modifiers(lines)

	var desktop_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var path: String = desktop_dir.path_join("GemforgeSurvivors_Full_Design_Status.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Failed to write full design status report to Desktop.")
		return
	f.store_string("\n".join(lines))
	f.close()
	print("Full design status report generated on Desktop")
	_show_status_toast("Full design status report generated on Desktop")


func _append_characters_overview(lines: PackedStringArray) -> void:
	lines.append("=== 1) All Characters Overview ===")
	var class_ids: PackedStringArray = MetaProgression.Catalog.get_all_class_ids()
	for class_id in class_ids:
		var meta: Dictionary = MetaProgression.get_meta_level_data_for_class(class_id)
		var points: int = MetaProgression.get_points(class_id)
		var archetype: String = get_archetype_for_class(class_id)
		var start_weapon: String = _starting_weapon_name_for_class(class_id)
		var start_skill: String = _starting_skill_for_class(class_id)
		lines.append("- %s" % class_id)
		lines.append("  Base Stats: HP 120, Move Speed 450.0")
		lines.append("  Unique Passive: %s" % str(CLASS_PASSIVE_BLURBS.get(class_id, "N/A")))
		lines.append("  Starting Weapon + Skill: %s + %s" % [start_weapon, start_skill])
		lines.append("  Archetype: %s" % archetype)
		lines.append("  Meta: Level %d, EXP %d/%d, Skill Points %d" % [
			int(meta.get("level", 1)),
			int(meta.get("exp", 0)),
			int(meta.get("next", 1000)),
			points
		])
		var unlocked: Array = MetaProgression.get_unlocked_list(class_id)
		var tree: Dictionary = MetaProgression.Catalog.get_tree(class_id)
		var by_id: Dictionary = {}
		for row in tree.get("nodes", []):
			by_id[str(row.get("id", ""))] = row
		var major: PackedStringArray = []
		var minor: PackedStringArray = []
		for nid in unlocked:
			var nrow: Dictionary = by_id.get(str(nid), {})
			if nrow.is_empty():
				continue
			var title: String = str(nrow.get("title", nid))
			var kind: String = str(nrow.get("kind", ""))
			if kind == MetaProgression.Catalog.KIND_CENTER or kind == MetaProgression.Catalog.KIND_CORNER:
				major.append(title)
			else:
				minor.append(title)
		lines.append("  Unlocked Major Nodes: %s" % (", ".join(major) if major.size() > 0 else "none"))
		lines.append("  Unlocked Minor Nodes: %s" % (", ".join(minor) if minor.size() > 0 else "none"))
		lines.append("")


func _append_skills_overview(lines: PackedStringArray) -> void:
	lines.append("=== 2) All Skills / Skill Gems ===")
	var player: Node = _get_player_if_running()
	var global_dmg_mult: float = 1.0
	var global_cdr_mult: float = 1.0
	var global_proj_add: int = 0
	if player:
		global_dmg_mult = _safe_f(player, "stat_damage_mult", 1.0)
		global_cdr_mult = _safe_f(player, "meta_skill_cdr_mult", 1.0)
		global_proj_add = _safe_i(player, "extra_projectiles", 0)
	lines.append("Global Modifiers: damage x%s, cooldown x%s, +%d projectiles" % [
		str(snappedf(global_dmg_mult, 0.01)),
		str(snappedf(global_cdr_mult, 0.01)),
		global_proj_add
	])
	for skill_name in ALL_STARTING_SKILLS:
		var gem: SkillGemResource = _skill_name_to_gem(skill_name)
		var dmg: float = gem.damage * global_dmg_mult
		var cd: float = gem.cooldown * global_cdr_mult
		lines.append("- %s" % skill_name)
		lines.append("  Base: damage=%s, cooldown=%ss, type=%s" % [str(snappedf(gem.damage, 0.01)), str(snappedf(gem.cooldown, 0.01)), gem.gem_type])
		lines.append("  Current Effective (global): damage=%s, cooldown=%ss, projectiles/hits=%d" % [
			str(snappedf(dmg, 0.01)),
			str(snappedf(cd, 0.01)),
			1 + global_proj_add
		])
	lines.append("")


func _append_level_up_catalog(lines: PackedStringArray) -> void:
	lines.append("=== 3) Level Up Rewards Catalog ===")
	var rows: Array = LEVEL_UP_BUFF_CATALOG.BUFF_ROWS
	for row in rows:
		var bid: String = str(row.get("id", ""))
		var rarity: String = str(row.get("rarity", "common")).capitalize()
		var title: String = str(row.get("title", "Unknown"))
		var desc: String = str(row.get("description", ""))
		var mode := "Compounding multiplier"
		if bid.contains("_proj_") or bid.contains("_hp_") or bid.contains("_lifesteal_") or bid.contains("_summon_") or bid.contains("_pierce_"):
			mode = "Additive flat value"
		elif bid.contains("_double_") or bid.contains("_invuln_"):
			mode = "Temporary/special effect"
		lines.append("- [%s] %s (%s)" % [rarity, title, bid])
		lines.append("  Description: %s" % desc)
		lines.append("  Application: %s" % mode)
	lines.append("")


func _append_gear_system(lines: PackedStringArray) -> void:
	lines.append("=== 4) Gear System ===")
	lines.append("Archetypes and core bonuses (Normal quality):")
	lines.append("- Heavy Weapon: %s" % _fmt_dict(_core_bonus_for_item("weapon", ARCHETYPE_HEAVY, "normal")))
	lines.append("- Light Weapon: %s" % _fmt_dict(_core_bonus_for_item("weapon", ARCHETYPE_LIGHT, "normal")))
	lines.append("- Arcane Weapon: %s" % _fmt_dict(_core_bonus_for_item("weapon", ARCHETYPE_ARCANE, "normal")))
	lines.append("- Heavy Armor: %s" % _fmt_dict(_core_bonus_for_item("armor", ARCHETYPE_HEAVY, "normal")))
	lines.append("- Light Armor: %s" % _fmt_dict(_core_bonus_for_item("armor", ARCHETYPE_LIGHT, "normal")))
	lines.append("- Arcane Armor: %s" % _fmt_dict(_core_bonus_for_item("armor", ARCHETYPE_ARCANE, "normal")))
	lines.append("Drop Weighting Rules:")
	lines.append("- Chest/Boss: 85% on-class archetype, 15% off-class random archetype")
	lines.append("- All dropped gear in current implementation: Normal quality, 1 empty socket")
	lines.append("Example Normal Gear:")
	lines.append("- Heavy: Guardian's Hammer [Weapon / Heavy], socket_count=1")
	lines.append("- Light: Hunter's Bow [Weapon / Light], socket_count=1")
	lines.append("- Arcane: Old Wand [Weapon / Arcane], socket_count=1")
	lines.append("")


func _append_current_run_modifiers(lines: PackedStringArray) -> void:
	lines.append("=== 5) Current Run Modifiers ===")
	if not is_in_run:
		lines.append("No active run.")
		lines.append("")
		return
	var player: Node = _get_player_if_running()
	if player == null:
		lines.append("Run active but player data unavailable.")
		lines.append("")
		return
	lines.append("- XP Gain Mult: x%s" % str(_safe_f(player, "xp_gain_mult", 1.0)))
	lines.append("- Damage Mult: x%s" % str(_safe_f(player, "stat_damage_mult", 1.0)))
	lines.append("- Attack Speed Mult: x%s" % str(_safe_f(player, "stat_attack_speed_mult", 1.0)))
	lines.append("- Cooldown Mult: x%s" % str(_safe_f(player, "meta_skill_cdr_mult", 1.0)))
	lines.append("- Area Mult: x%s" % str(_safe_f(player, "stat_area_mult", 1.0)))
	lines.append("- Pickup Radius Mult: x%s" % str(_safe_f(player, "pickup_radius_mult", 1.0)))
	lines.append("- Extra Projectiles: %d" % _safe_i(player, "extra_projectiles", 0))
	lines.append("")


func _get_player_if_running() -> Node:
	return get_tree().get_first_node_in_group("player")


func _safe_f(node: Node, prop: String, fallback: float) -> float:
	if node != null and (prop in node):
		return float(node.get(prop))
	return fallback


func _safe_i(node: Node, prop: String, fallback: int) -> int:
	if node != null and (prop in node):
		return int(node.get(prop))
	return fallback


func _fmt_dict(v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return str(v)
	var d: Dictionary = v
	if d.is_empty():
		return "-"
	var parts: PackedStringArray = []
	var keys := d.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [str(k), str(d[k])])
	return ", ".join(parts)


func _show_status_toast(message: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 300
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = 10
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -320
	label.offset_right = 320
	label.offset_top = 20
	label.offset_bottom = 56
	label.modulate = Color(1, 1, 1, 0.95)
	layer.add_child(label)
	var t := layer.create_tween()
	t.tween_interval(1.2)
	t.tween_property(label, "modulate:a", 0.0, 0.45)
	t.finished.connect(layer.queue_free)


func save_equipment_state() -> void:
	var data: Dictionary = {
		"equipped_by_class": equipped_by_class.duplicate(true),
		"inventory_by_class": inventory_by_class.duplicate(true),
		"blank_gems_by_class": blank_gems_by_class.duplicate(true),
		"loose_skill_gems_by_class": loose_skill_gems_by_class.duplicate(true),
	}
	var f := FileAccess.open(EQUIP_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameManager: failed to save equipment state")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	print("Equipment state saved.")


func _load_equipment_state() -> void:
	if not FileAccess.file_exists(EQUIP_SAVE_PATH):
		return
	var f := FileAccess.open(EQUIP_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	equipped_by_class = d.get("equipped_by_class", {})
	inventory_by_class = d.get("inventory_by_class", {})
	blank_gems_by_class = d.get("blank_gems_by_class", {})
	loose_skill_gems_by_class = d.get("loose_skill_gems_by_class", {})
	print("Equipment state loaded.")
