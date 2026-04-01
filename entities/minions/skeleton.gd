extends CharacterBody2D

@export var speed: float = 180.0
@export var max_health: int = 40
@export var contact_damage: int = 12
@export var contact_range: float = 36.0
@export var contact_cooldown: float = 1.15

var health: int = 40
var _contact_cd: float = 0.0
var _is_dying: bool = false

@onready var _health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	health = max_health
	add_to_group("friendly_minion")
	_sync_health_bar()
	print("Skeleton summoned at ", global_position)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)

	var target: Node2D = _nearest_enemy()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	if to_target.length() > contact_range:
		velocity = to_target.normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if _contact_cd <= 0.0 and target.has_method("take_damage"):
			target.call("take_damage", contact_damage)
			_contact_cd = contact_cooldown


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D):
			continue
		var n2 := n as Node2D
		var d2 := global_position.distance_squared_to(n2.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n2
	return best


func take_damage(amount: int) -> void:
	if _is_dying:
		return
	health -= amount
	_sync_health_bar()
	if health <= 0:
		_die()


func _sync_health_bar() -> void:
	if _health_bar:
		_health_bar.max_value = float(max_health)
		_health_bar.value = float(maxi(0, health))


func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	queue_free()
