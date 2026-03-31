extends Node2D
## Brief floating text at a world position; fades and drifts upward.

const FLOAT_OFFSET := Vector2(0, -56)
const DRIFT := Vector2(0, -36)
const LIFETIME := 3.5

var _lines: PackedStringArray = []


func setup(world_position: Vector2, lines: PackedStringArray) -> void:
	global_position = world_position + FLOAT_OFFSET
	z_index = 80
	_lines = lines


func _ready() -> void:
	var parts: PackedStringArray = []
	for line in _lines:
		if str(line) != "":
			parts.append(str(line))
	var lb := Label.new()
	lb.text = "\n".join(parts)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1))
	lb.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 1))
	lb.add_theme_constant_override("outline_size", 4)
	add_child(lb)
	await get_tree().process_frame
	lb.position = -lb.size * 0.5
	_play_fade()


func _play_fade() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", global_position + DRIFT, LIFETIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, LIFETIME).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
