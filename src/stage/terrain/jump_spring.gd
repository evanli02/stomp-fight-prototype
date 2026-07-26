class_name JumpSpring extends TerrainElement
## Fixed strong launch on contact (DESIGN 6.2). Overrides the vertical component
## and leaves horizontal alone, so a spring keeps whatever run you brought into
## it — that is what makes springs chainable with b-hops.

@export var launch_velocity: Vector2 = Vector2(0, -700)
@export var retrigger: float = 0.25
var _cooldown: Dictionary = {}
var _squash: float = 0.0

func tick(delta: float) -> void:
	for id in _cooldown.keys():
		_cooldown[id] -= delta
		if _cooldown[id] <= 0.0:
			_cooldown.erase(id)
	if _squash > 0.0:
		_squash = maxf(_squash - delta * 4.0, 0.0)
		queue_redraw()

func on_body_entered(p: Player) -> void:
	var id := p.get_instance_id()
	if _cooldown.has(id):
		return
	_cooldown[id] = retrigger
	p.set_velocity_override(Vector2(p.velocity.x + launch_velocity.x, launch_velocity.y))
	# Must leave the grounded state explicitly: Idle and Run set velocity.y = 0
	# every frame a body is on the floor, so a launch applied to a standing
	# player is erased before it ever moves them.
	p.request_state(&"Air", {"anim": &"rise"})
	# A launch is a fresh start in the air, not a landing.
	p.air_dash_locked = false
	_squash = 1.0

func _draw() -> void:
	var half := size * 0.5
	var press := _squash * 6.0
	draw_rect(Rect2(Vector2(-half.x, half.y - 5), Vector2(size.x, 5)), Color(0.36, 0.36, 0.48))
	var plate := Rect2(-half.x + 2, -half.y + press, size.x - 4, 6)
	draw_rect(plate, Color(0.24, 0.86, 0.52))
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2)), Color(0.64, 0.98, 0.78))
	for i in 3:
		var y := -half.y + 8 + press + i * 4
		draw_rect(Rect2(-half.x + 5, y, size.x - 10, 2), Color(0.2, 0.2, 0.3))
