extends Node

# Global run state: current class, whether a run is active, and run timer (wire up later).

signal run_started
signal run_ended(success: bool)
signal meta_xp_gained(amount: int)

# Holds the ClassData resource the player picked for this run (inspector / menu will set later).
var current_class: ClassData
var is_in_run: bool = false
var run_time: float = 0.0

const EQUIP_SAVE_PATH := "user://equipment_state.json"
const SLOT_TYPES := ["weapon", "armor", "boots", "accessory"]
const ARCHETYPE_HEAVY := "Heavy"
const ARCHETYPE_LIGHT := "Light"
const ARCHETYPE_ARCANE := "Arcane"

# Per-class equipment state.
var equipped_by_class: Dictionary = {} # class_id -> {slot_type: item_dict}
var inventory_by_class: Dictionary = {} # class_id -> Array[item_dict]
var blank_gems_by_class: Dictionary = {} # class_id -> int
var loose_skill_gems_by_class: Dictionary = {} # class_id -> Array[String]


func _ready() -> void:
	_load_equipment_state()
	print("GameManager autoload ready")


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


func gamble_gear_for_class(class_key: String, forced_slot: String = "") -> Dictionary:
	var key := _class_key_or_default(class_key)
	_ensure_class_state(key)
	var slot_type := forced_slot.to_lower()
	if slot_type == "" or slot_type not in SLOT_TYPES:
		slot_type = String(SLOT_TYPES[randi() % SLOT_TYPES.size()])
	var rarity := "normal"
	var archetype: String = get_archetype_for_class(key)
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
