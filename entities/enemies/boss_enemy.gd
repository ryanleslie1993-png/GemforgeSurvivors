extends CharacterBody2D

@export var max_health: float = 800.0
@export var speed: float = 80.0
@export var boss_name: String = "Boss"
@export var contact_damage: int = 15
@export var contact_cooldown: float = 0.6

var health: float = 0.0
var _is_dying: bool = false
var _contact_cd: float = 0.0
var health_bar: ProgressBar = null
var _offscreen_linger: float = 0.0


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	add_to_group("bosses")
	health_bar = get_node_or_null("HealthBar") as ProgressBar
	_sync_health_bar()
	print("Boss spawned: ", boss_name, " (HP ", max_health, ")")


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()
	_update_boss_offscreen_teleport(delta, player)
	if _contact_cd <= 0.0 and global_position.distance_to(player.global_position) < 54.0 and player.has_method("take_damage"):
		player.call("take_damage", contact_damage)
		_contact_cd = contact_cooldown


func take_damage(amount: float) -> void:
	if _is_dying:
		return
	health -= amount
	_sync_health_bar()
	if health <= 0.0:
		die()


func _sync_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = maxf(0.0, health)


func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	print("Boss ", boss_name, " defeated!")
	call_deferred("_deferred_boss_die")


func _deferred_boss_die() -> void:
	var pos := global_position
	var bname := boss_name
	var arena := get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("on_boss_died"):
		arena.call("on_boss_died", bname, pos)
	queue_free()


const BOSS_OFFSCREEN_DIST_SQ: float = 1250.0 * 1250.0
const BOSS_OFFSCREEN_LINGER_SEC: float = 3.0


func _update_boss_offscreen_teleport(delta: float, player: Node2D) -> void:
	if _is_dying or player == null:
		_offscreen_linger = 0.0
		return
	if global_position.distance_squared_to(player.global_position) > BOSS_OFFSCREEN_DIST_SQ:
		_offscreen_linger += delta
		if _offscreen_linger >= BOSS_OFFSCREEN_LINGER_SEC:
			var fwd := Vector2.RIGHT
			if player is CharacterBody2D:
				var pv := (player as CharacterBody2D).velocity
				if pv.length_squared() > 90.0:
					fwd = pv.normalized()
				else:
					fwd = (global_position - player.global_position).normalized()
			global_position = player.global_position + fwd * randf_range(380.0, 520.0)
			_offscreen_linger = 0.0
			print("Boss off-screen linger — repositioned ahead of player")
	else:
		_offscreen_linger = 0.0
