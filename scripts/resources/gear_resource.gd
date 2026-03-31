extends Resource
class_name GearResource

@export_category("Gear")
@export var gear_name: String = ""
@export_enum("weapon", "armor", "boots", "accessory") var slot_type: String = "weapon"
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export var socketed_gem: SkillGemResource

# class_name GearResource registers this type globally for equipment data.
