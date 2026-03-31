extends Area2D
## Placeholder fireball: red shape that travels in a straight line.
## Swap mesh/sprite for real art later; hook body_entered into damage when enemies exist.

@export var speed: float = 420.0
@export var max_lifetime: float = 4.0

## Set by spawner (player) from the skill gem.
var damage: float = 10.0
var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	# Projectile on its own layer so we do not collide with the player (layer 1) by default.
	collision_layer = 2
	collision_mask = 4
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(max_lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	print("Fireball hit body (damage later): ", body.name, " dmg=", damage)
	queue_free()


