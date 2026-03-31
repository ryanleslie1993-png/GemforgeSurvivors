extends Node2D
## Repeating grass/forest tiles around the camera. Use parallax_factor < 1 for a deeper layer that scrolls slower.

@export var tile_size: float = 96.0
@export var tiles_half_extent: int = 13
@export var parallax_factor: float = 1.0
@export var color_a: Color = Color(0.085, 0.24, 0.11, 1.0)
@export var color_b: Color = Color(0.12, 0.32, 0.14, 1.0)
@export var grid_line_width: float = 1.0
@export var grid_stride_tiles: int = 4
@export var grid_alpha: float = 0.2


func _ready() -> void:
	set_process(true)
	print("Infinite grass layer ready (tile=", tile_size, ", parallax=", parallax_factor, ")")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var focus := Vector2.ZERO
	if cam:
		focus = cam.global_position * parallax_factor
	else:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			focus = p.global_position * parallax_factor

	var ci := int(floor(focus.x / tile_size))
	var cj := int(floor(focus.y / tile_size))
	var hs: int = tiles_half_extent
	var ts := tile_size

	for i in range(-hs, hs + 1):
		for j in range(-hs, hs + 1):
			var wx: float = float(ci + i) * ts
			var wy: float = float(cj + j) * ts
			var tl: Vector2 = to_local(Vector2(wx, wy))
			var alt := posmod(ci + i + cj + j, 2)
			var col: Color = color_a if alt == 0 else color_b
			draw_rect(Rect2(tl, Vector2(ts, ts)), col)

			if grid_alpha > 0.01 and grid_stride_tiles > 0:
				if posmod(ci + i, grid_stride_tiles) == 0:
					draw_line(tl, tl + Vector2(0.0, ts), Color(color_a.r * 0.5, color_a.g * 0.85, color_a.b * 0.65, grid_alpha), grid_line_width)
				if posmod(cj + j, grid_stride_tiles) == 0:
					draw_line(tl, tl + Vector2(ts, 0.0), Color(color_a.r * 0.5, color_a.g * 0.85, color_a.b * 0.65, grid_alpha), grid_line_width)
