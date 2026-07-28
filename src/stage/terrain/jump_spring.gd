class_name JumpSpring extends TerrainElement
## Fixed strong launch on contact (DESIGN 6.2). Replaces the component of your
## velocity ALONG its launch axis and leaves the perpendicular one alone, so an
## upward spring keeps whatever run you brought into it - that is what makes
## springs chainable with b-hops - and a spring mounted on a wall flings you
## sideways without eating your fall.
##
## Axis rather than "vertical" so wall springs work at all: written the old way,
## a horizontal launch_velocity set velocity.y to zero and left velocity.x to be
## added to, which is the opposite of what a sideways spring should do.

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
	var axis := launch_velocity.normalized()
	var tangent := p.velocity - axis * p.velocity.dot(axis)
	p.set_velocity_override(tangent + launch_velocity)
	# Must leave the grounded state explicitly: Idle and Run set velocity.y = 0
	# every frame a body is on the floor, so a launch applied to a standing
	# player is erased before it ever moves them.
	p.request_state(&"Air", {"anim": &"rise"})
	# A launch is a fresh start in the air, not a landing.
	p.air_dash_locked = false
	_squash = 1.0
	Audio.play(&"spring")

## Drawn in a frame where the launch always points up, then rotated onto the real
## axis. Written flat, the plate was pinned to the element's top edge and the
## base to its bottom, so a spring mounted on a wall drew a squashed upward
## spring inside a tall box instead of a sideways one.
func _draw() -> void:
	var axis := launch_velocity.normalized()
	if axis == Vector2.ZERO:
		axis = Vector2.UP
	# Which of the element's dimensions runs along the launch, and which across.
	var sideways: bool = absf(axis.x) > absf(axis.y)
	var depth: float = size.x if sideways else size.y
	var across: float = size.y if sideways else size.x
	# Vector2.UP.angle() is -PI/2, so this is the turn that carries "up" onto the
	# launch direction.
	draw_set_transform(Vector2.ZERO, axis.angle() + PI * 0.5, Vector2.ONE)

	var half := Vector2(across, depth) * 0.5
	var press := _squash * minf(6.0, depth * 0.4)
	draw_rect(Rect2(Vector2(-half.x, half.y - 5), Vector2(across, 5)),
		Color(0.36, 0.36, 0.48))
	var plate := Rect2(-half.x + 2, -half.y + press, across - 4, 6)
	draw_rect(plate, Color(0.24, 0.86, 0.52))
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2)), Color(0.64, 0.98, 0.78))
	# Coils between plate and base, so a tall wall spring does not read as a bar.
	var coil_top := plate.position.y + 6.0
	var coil_h := (half.y - 5.0) - coil_top
	if coil_h > 3.0:
		for i in 3:
			var x := -half.x + 4.0 + (across - 8.0) * (float(i) + 0.5) / 3.0
			draw_rect(Rect2(Vector2(x - 1.0, coil_top), Vector2(2.0, coil_h)),
				Color(0.24, 0.86, 0.52, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
