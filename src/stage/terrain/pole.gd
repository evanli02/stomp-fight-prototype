class_name Pole extends TerrainElement
## Grab to zero momentum instantly, crawl up and down, jump off either side
## (DESIGN 6.2). The movement "reset button": everything else in the kit is about
## keeping speed, and this is the one thing that deliberately throws it away in
## exchange for control.
##
## Holding down drops past it, so a pole in a fall line is never a trap.

@export var climb_speed: float = 140.0
@export var jump_off_impulse: Vector2 = Vector2(280, -420)

func on_body_entered(p: Player) -> void:
	if p.stun_remaining > 0.0 or p.wants_crouch():
		return
	if p.state_machine.state_name() == &"PoleClimb":
		return
	p.request_state(&"PoleClimb", {
		"pole_x": global_position.x,
		"climb_speed": climb_speed,
		"jump_off": jump_off_impulse,
		"top": global_position.y - size.y * 0.5,
		"bottom": global_position.y + size.y * 0.5,
	})

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(Vector2(-2, -half.y), Vector2(4, size.y)), Color(0.72, 0.72, 0.82))
	draw_rect(Rect2(Vector2(-2, -half.y), Vector2(2, size.y)), Color(0.96, 0.96, 0.98))
	for i in int(size.y / 12.0):
		draw_rect(Rect2(Vector2(0, -half.y + i * 12), Vector2(2, 2)), Color(0.36, 0.36, 0.48))
