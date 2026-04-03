extends Resource
class_name SkillGemResource
## Data for socketed skill gems. `cooldown` + `damage` drive the placeholder auto-fire projectile loop.

@export_category("Skill Gem")
@export var gem_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var cooldown: float = 1.0
@export var damage: float = 10.0
## "projectile" gems are picked up by the player's auto-fire (see player.gd).
@export_enum("projectile", "aura", "summon", "melee", "channel", "transformation") var gem_type: String = "projectile"
## Auto-cast behavior: ON for attacks, OFF for buffs/transformations by default.
@export var auto_cast: bool = true

# class_name SkillGemResource registers this type globally (e.g. GearResource.socketed_gem).
