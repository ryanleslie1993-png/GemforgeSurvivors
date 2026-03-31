extends Area2D
## Short-lived ground patch: one damage pulse + slow on enemies in radius at spawn.

@export var damage: int = 12
@export var slow_duration: float = 2.0
## Lower = stronger slow (movement multiplier on enemy).
@export var slow_factor: float = 0.52
@export var visual_fade_sec: float = 0.55


func _ready() -> void:
	get_tree().create_timer(visual_fade_sec).timeout.connect(queue_free)
	await get_tree().physics_frame
	_apply_to_overlapping()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property($Ring, "modulate:a", 0.0, visual_fade_sec * 0.92)
	tw.tween_property($Inner, "modulate:a", 0.0, visual_fade_sec * 0.92)


func _apply_to_overlapping() -> void:
	var seen: Dictionary = {}
	for body in get_overlapping_bodies():
		if body in seen:
			continue
		seen[body] = true
		_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	if body.has_method("apply_slow"):
		body.call("apply_slow", slow_duration, slow_factor)
