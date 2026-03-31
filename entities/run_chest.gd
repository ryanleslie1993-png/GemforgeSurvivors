extends Area2D

var _opened: bool = false
var _pulse_t: float = 0.0


func _ready() -> void:
	set_process(true)
	body_entered.connect(_on_body_entered)
	print("Run chest spawned at ", global_position)


func _process(delta: float) -> void:
	_pulse_t += delta * 3.0
	var pulse := 0.5 + 0.5 * sin(_pulse_t)
	if has_node("Glow"):
		$Glow.modulate.a = 0.38 + 0.28 * pulse
	if has_node("OuterGlow"):
		$OuterGlow.modulate.a = 0.2 + 0.22 * (0.5 + 0.5 * sin(_pulse_t * 0.82))
	if has_node("OuterRing"):
		$OuterRing.modulate.a = 0.55 + 0.25 * pulse


func _on_body_entered(body: Node2D) -> void:
	if _opened:
		return
	if not body.is_in_group("player"):
		return
	_opened = true
	var pos := global_position
	call_deferred("_deferred_open_and_free", pos)


func _deferred_open_and_free(pos: Vector2) -> void:
	for n in get_tree().get_nodes_in_group("run_arena"):
		if n.has_method("open_chest"):
			n.call("open_chest", pos)
	queue_free()
