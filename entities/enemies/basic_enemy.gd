extends CharacterBody2D

@export var speed: float = 120.0
@export var max_health: int = 50
@export var contact_damage: int = 8
@export var contact_range: float = 42.0
@export var contact_cooldown: float = 0.55
var health: int = 50
var _contact_cd: float = 0.0
var _is_dying: bool = false

var _base_speed: float = 120.0
var _knockback_vel: Vector2 = Vector2.ZERO

## Burn: damage ticks until timer expires (refreshes if reapplied).
var _burn_remaining: float = 0.0
var _burn_tick_accum: float = 0.0
var _burn_tick_damage_mult: float = 1.0
@export var burn_tick_damage: int = 2
@export var burn_tick_interval: float = 0.48

## Slow: multiplier on move speed (0.5 = half speed).
var _slow_remaining: float = 0.0
var _slow_factor: float = 1.0

## If stuck far from the player too long, snap ahead of their movement.
var _offscreen_linger: float = 0.0

@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_base_speed = speed
	_sync_health_bar()


func _sync_health_bar() -> void:
	if health_bar:
		health_bar.max_value = float(max_health)
		health_bar.value = float(health)


func apply_knockback(from_global: Vector2, impulse: float) -> void:
	var away := global_position - from_global
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	_knockback_vel += away.normalized() * impulse


func apply_burn(duration_sec: float, tick_damage_mult: float = 1.0) -> void:
	_burn_remaining = maxf(_burn_remaining, duration_sec)
	_burn_tick_damage_mult = maxf(_burn_tick_damage_mult, tick_damage_mult)


func apply_slow(duration_sec: float, move_factor: float = 0.52) -> void:
	_slow_remaining = maxf(_slow_remaining, duration_sec)
	_slow_factor = move_factor


func _apply_burn_tick_damage(amount: int) -> void:
	var scaled: int = int(round(float(amount) * _burn_tick_damage_mult))
	health -= scaled
	_sync_health_bar()
	print("Burn tick: ", scaled, " (enemy HP ", health, ")")
	if health <= 0:
		die()


func _physics_process(delta: float) -> void:
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_process_burn(delta)
	_process_slow(delta)
	_update_debuff_visual()

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var target := _pick_chase_target(player)
	var direction := Vector2.ZERO
	if target:
		direction = (target.global_position - global_position).normalized()

	var eff_speed: float = _base_speed
	if _slow_remaining > 0.0:
		eff_speed *= _slow_factor

	_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 520.0 * delta)
	velocity = direction * eff_speed + _knockback_vel
	move_and_slide()

	_update_offscreen_teleport(delta, player)

	if _contact_cd > 0.0:
		return

	var touching := false
	for i in get_slide_collision_count():
		var kc := get_slide_collision(i)
		var collider := kc.get_collider()
		if collider and (collider.is_in_group("player") or collider.is_in_group("friendly_minion")):
			touching = true
			break

	if not touching and target:
		touching = global_position.distance_to(target.global_position) < contact_range

	if touching and target and target.has_method("take_damage"):
		target.call("take_damage", contact_damage)
		_contact_cd = contact_cooldown


func _pick_chase_target(player: Node2D) -> Node2D:
	var best: Node2D = player
	var best_d2: float = INF
	if player:
		best_d2 = global_position.distance_squared_to(player.global_position)
	for n in get_tree().get_nodes_in_group("friendly_minion"):
		if not (n is Node2D):
			continue
		var n2 := n as Node2D
		var d2 := global_position.distance_squared_to(n2.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n2
	return best


func _process_burn(delta: float) -> void:
	if _burn_remaining <= 0.0:
		return
	_burn_remaining -= delta
	_burn_tick_accum += delta
	while _burn_tick_accum >= burn_tick_interval:
		_burn_tick_accum -= burn_tick_interval
		_apply_burn_tick_damage(burn_tick_damage)


func _process_slow(delta: float) -> void:
	if _slow_remaining > 0.0:
		_slow_remaining -= delta


func _update_debuff_visual() -> void:
	if _burn_remaining > 0.0 and _slow_remaining > 0.0:
		modulate = Color(0.95, 0.72, 0.55)
	elif _slow_remaining > 0.0:
		modulate = Color(0.72, 0.92, 1.08)
	elif _burn_remaining > 0.0:
		modulate = Color(1.1, 0.55, 0.35)
	else:
		modulate = Color.WHITE


func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	var pos := global_position
	call_deferred("_deferred_die_notify_and_free", pos)


func _deferred_die_notify_and_free(pos: Vector2) -> void:
	for n in get_tree().get_nodes_in_group("run_arena"):
		if n.has_method("on_enemy_died"):
			n.call("on_enemy_died", pos)
	queue_free()


func take_damage(amount: int) -> void:
	health -= amount
	_sync_health_bar()
	print("Enemy took ", amount, " damage. Health left: ", health)
	if health <= 0:
		die()


const OFFSCREEN_DIST_SQ: float = 1100.0 * 1100.0
const OFFSCREEN_LINGER_SEC: float = 3.0


func _update_offscreen_teleport(delta: float, player: Node2D) -> void:
	if _is_dying or player == null:
		_offscreen_linger = 0.0
		return
	if global_position.distance_squared_to(player.global_position) > OFFSCREEN_DIST_SQ:
		_offscreen_linger += delta
		if _offscreen_linger >= OFFSCREEN_LINGER_SEC:
			_teleport_near_player_front(player)
			_offscreen_linger = 0.0
	else:
		_offscreen_linger = 0.0


func _teleport_near_player_front(player: Node2D) -> void:
	var fwd := Vector2.RIGHT
	if player is CharacterBody2D:
		var pv := (player as CharacterBody2D).velocity
		if pv.length_squared() > 90.0:
			fwd = pv.normalized()
		else:
			fwd = (global_position - player.global_position).normalized()
	global_position = player.global_position + fwd * randf_range(340.0, 500.0)
	_knockback_vel *= 0.25
	print("Enemy off-screen > ", OFFSCREEN_LINGER_SEC, "s — teleporting into player forward arc")
