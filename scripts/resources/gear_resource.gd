extends Resource
class_name GearResource

@export_category("Gear")
@export var gear_name: String = ""
@export var gear_type: String = "Weapon" # Weapon, Armor, Boots, Helm, etc.
@export var archetype: String = "Heavy" # Heavy, Light, Arcane
@export var rarity: String = "Normal"
@export var core_bonus: String = ""
@export var core_bonus_values: Dictionary = {}
@export var socket_count: int = 1
@export var stats: Dictionary = {}
@export var socketed_gem: SkillGemResource

# class_name GearResource registers this type globally for equipment data.
