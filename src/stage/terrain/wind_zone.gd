class_name WindZone extends TerrainElement
## Constant directional force, no stun (DESIGN 6.2). Airborne players are pushed
## about twice as hard as grounded ones — on the ground you have friction to
## brace against, in the air you have nothing.

@export var force: Vector2 = Vector2(300, 0)
@export var airborne_multiplier: float = 2.0

func physics_effect(p: Player, delta: float) -> void:
	var scale := 1.0 if p.is_on_floor() else airborne_multiplier
	p.apply_impulse(force * scale * delta)

func tick(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(0.18, 0.89, 0.90, 0.07))
	var drift := fmod(float(Time.get_ticks_msec()) * 0.08 * signf(force.x), 24.0)
	for row in int(size.y / 18.0):
		var y := -half.y + 9 + row * 18
		for i in int(size.x / 24.0) + 1:
			var x := -half.x + fmod(i * 24 + drift + 24.0, size.x)
			draw_rect(Rect2(x - half.x * 0 + -0, y, 10, 1),
				Color(0.49, 0.98, 1.0, 0.5))
