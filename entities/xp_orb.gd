extends Area2D
## Touch or magnetic pickup within player pickup radius.

@export var xp_value: int = 10

const BASE_TOUCH_RADIUS: float = 22.0
var _collected: bool = false


func _ready() -> void:
	set_physics_process(true)
	body_entered.connect(_on_body_entered)
	add_to_group("xp_orb")
	print("XP orb spawned (+", xp_value, " XP)")


func _physics_process(_delta: float) -> void:
	if _collected:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var pr: float = BASE_TOUCH_RADIUS
	if player.has_method("get_effective_pickup_radius"):
		pr = float(player.call("get_effective_pickup_radius"))
	if global_position.distance_to(player.global_position) <= pr:
		_collect(player)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collect(body)


func _collect(body: Node) -> void:
	if _collected:
		return
	_collected = true
	if body and body.has_method("add_xp"):
		body.call("add_xp", xp_value)
		print("Collected XP orb: +", xp_value)
	queue_free()
