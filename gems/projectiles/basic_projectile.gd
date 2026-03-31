extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: int = 25
var projectile_color: Color = Color(1, 0.85, 0.25)
var max_lifetime: float = 3.0
var scale_mult: float = 1.0

var burn_duration: float = 0.0
var burn_tick_damage_mult: float = 1.0
## How many enemy hits before this projectile is removed (1 = no pierce).
var pierce_hits_remaining: int = 1

var holy_heal_fraction: float = 0.0
var life_steal_flat: int = 0
var source_skill: String = ""

var _hit_bodies: Array[Node2D] = []


func _ready() -> void:
	pierce_hits_remaining = maxi(1, pierce_hits_remaining)
	if has_node("Sprite"):
		$Sprite.modulate = projectile_color
		$Sprite.scale *= scale_mult
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(max_lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if not body.has_method("take_damage"):
		return
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)

	body.call("take_damage", damage)
	get_tree().call_group("run_arena", "record_skill_damage", source_skill, damage)

	if burn_duration > 0.0 and body.has_method("apply_burn"):
		body.call("apply_burn", burn_duration, burn_tick_damage_mult)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		if holy_heal_fraction > 0.0 and player.has_method("heal"):
			var h: int = int(round(float(damage) * holy_heal_fraction))
			if h > 0:
				player.call("heal", h)
		if life_steal_flat > 0 and player.has_method("heal"):
			player.call("heal", life_steal_flat)

	pierce_hits_remaining -= 1
	if pierce_hits_remaining <= 0:
		queue_free()
