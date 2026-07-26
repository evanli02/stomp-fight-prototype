class_name SlashTrail extends Node2D
## The afterimage of Sai's ultimate: the line he travelled, drawn for a beat and
## gone. The hit already resolved the instant he moved.

const LIFE: float = 0.3

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
var accent: Color = Color(1, 0.43, 0.78)
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / LIFE, 0.0, 1.0)
	var a := to_local(from_point)
	var b := to_local(to_point)
	draw_line(a, b, Color(accent.r, accent.g, accent.b, fade * 0.9), 4.0)
	draw_line(a, b, Color(1, 1, 1, fade), 1.5)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	for t: float in [0.25, 0.5, 0.75]:
		var at := a + (b - a) * t
		draw_line(at - n * 6.0, at + n * 6.0,
			Color(accent.r, accent.g, accent.b, fade * 0.5), 1.0)
