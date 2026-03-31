extends Node

# Global run state: current class, whether a run is active, and run timer (wire up later).

signal run_started
signal run_ended(success: bool)
signal meta_xp_gained(amount: int)

# Holds the ClassData resource the player picked for this run (inspector / menu will set later).
var current_class: ClassData
var is_in_run: bool = false
var run_time: float = 0.0


func _ready() -> void:
	print("GameManager autoload ready")
