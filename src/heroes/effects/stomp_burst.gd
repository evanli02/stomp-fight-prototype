class_name StompBurst extends Node2D
## The kill-confirm flash: an eight-spoke comic starburst in the attacker's
## accent colour, spawned at the victim's head on every stomp. Purely visual —
## the stomp itself already resolved before this exists.

const LIFE: float = 0.32

var accent: Color = Color(1, 0.55, 0.18)
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / LIFE, 0.0, 1.0)
	var fade := 1.0 - t
	var r := 10.0 + 34.0 * t
	# Double ring...
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, fade), 3.0)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 24, Color(1, 1, 1, fade * 0.7), 1.5)
	# ...and comic spokes shooting past it.
	for i in 8:
		var ang := i * TAU / 8.0 + 0.4
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * r * 0.8, dir * (r * 1.25 + 6.0),
			Color(accent.r, accent.g, accent.b, fade), 2.0)
	draw_circle(Vector2.ZERO, 4.0 * fade, Color(1, 1, 1, fade))
