extends Resource
class_name ClassData

@export_category("Class Data")
# Not named "class_name" — that word is reserved for `class_name ClassData` above; using it as a
# variable breaks parsing and triggers "Could not parse global class 'ClassData'".
@export var character_class_name: String = ""
@export var description: String = ""
@export var starting_health: int = 100
@export var starting_speed: float = 300.0
@export var unique_passive: String = ""

# The line `class_name ClassData` above registers this script as a global type for GameManager etc.
