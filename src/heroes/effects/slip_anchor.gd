class_name SlipAnchor extends Node2D
## The visible marker for Slip's anchor. It is the whole reason the ability is
## readable: without a mark on the ground, neither Slip nor her opponent can see
## where the rewind goes, and a blink to an invisible point is unreadable for
## both of them.
##
## Purely cosmetic — the ability owns the real anchor. This just watches the
## clock it was handed and shows how much of it is left.

var accent: Color = Color(0.11, 0.43, 0.82)
var duration: float = 6.0
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var left: float = clampf(1.0 - _age / duration, 0.0, 1.0)
	var pulse: float = 0.65 + 0.35 * sin(_age * 9.0)
	# Diamond: distinct from every circular effect in the game at a glance.
	var r := 9.0
	var pts := PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.22 * pulse))
	for i in 4:
		draw_line(pts[i], pts[(i + 1) % 4], Color(accent.r, accent.g, accent.b, pulse), 2.0)
	# Time left, drawn as an arc so it reads without a number.
	draw_arc(Vector2.ZERO, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24,
		Color(1, 1, 1, 0.75 * pulse), 2.0)
	draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, pulse))
