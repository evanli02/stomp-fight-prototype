class_name CleanseFlash extends Node2D
## The white pulse over a body Saint just cleaned. Short and bright: the whole
## job is telling both teams that the debuffs they were counting on are gone.

const LIFE: float = 0.35

var accent: Color = Color(0.95, 0.95, 0.98)
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
	# A ring lifting off the body, plus four rays: light leaving, not arriving.
	draw_arc(Vector2(0.0, -6.0 - 18.0 * t), 18.0 + 8.0 * t, 0.0, TAU, 28,
		Color(accent.r, accent.g, accent.b, fade * 0.85), 2.0)
	for i in 4:
		var ang := -PI * 0.5 + (float(i) - 1.5) * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * 8.0, dir * (14.0 + 16.0 * t), Color(1, 1, 1, fade * 0.7), 1.5)
