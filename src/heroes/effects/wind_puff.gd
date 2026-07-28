class_name WindPuff extends Node2D
## The little cloud Fei kicks off when she takes her air jump — the visual that
## says the wind is what she is standing on. A burst of puffy arcs at the cast
## point that spread and fade in under half a second. Purely cosmetic.

const LIFE: float = 0.4

var accent: Color = Color(0.24, 0.86, 0.52)
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / LIFE, 0.0, 1.0)
	var fade: float = 1.0 - t
	# Three puff lobes pushed outward and down, like a cloud being stepped on.
	for i in 3:
		var ang := PI * 0.25 + i * PI * 0.25   # fan across the lower half
		var at := Vector2(cos(ang), sin(ang) * 0.5) * (10.0 + 14.0 * t)
		var r := 6.0 - 2.0 * t
		draw_circle(at, r, Color(1, 1, 1, fade * 0.4))
		draw_arc(at, r + 1.0, 0.0, TAU, 12,
			Color(accent.r, accent.g, accent.b, fade * 0.6), 1.2)
	# Two trailing gust lines streaking out sideways.
	for side: float in [-1.0, 1.0]:
		var y := 4.0 + 3.0 * t
		draw_line(Vector2(side * 6.0, y), Vector2(side * (14.0 + 16.0 * t), y),
			Color(accent.r, accent.g, accent.b, fade * 0.5), 1.5)
