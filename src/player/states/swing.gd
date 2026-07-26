class_name SwingState extends PlayerState
## Hanging from Sai's grapple (DESIGN 5.2): a fixed-radius pendulum around the
## hook point. Gravity drives the swing; the body's velocity is set to the arc
## velocity every tick, so leaving — by jump, by drop, or by being forced off —
## keeps exactly the momentum the swing built. That is the whole point of the
## ability: it is a momentum machine, not a zipline.
##
## The rope has a patience limit: after the swing has reversed direction twice,
## it lets go. Committing to a swing means riding it, not camping under a hook.

const MAX_REVERSALS: int = 2
## Jump off the rope: the swing's velocity, plus a little launch along it.
const JUMP_BONUS: float = 1.08

var _anchor: Vector2 = Vector2.ZERO
var _radius: float = 60.0
var _theta: float = 0.0        ## angle from straight-down under the anchor
var _omega: float = 0.0        ## angular velocity, radians/s
var _reversals: int = 0
var _last_sign: float = 0.0

func enter(params: Dictionary = {}) -> void:
	_anchor = params.get("anchor", player.global_position + Vector2.UP * 60.0)
	var offset := player.global_position - _anchor
	_radius = maxf(offset.length(), 24.0)
	_theta = atan2(offset.x, offset.y)  # 0 = hanging straight down
	# Carry the entry speed into the arc: project velocity onto the tangent.
	var tangent := Vector2(cos(_theta), -sin(_theta))
	_omega = player.velocity.dot(tangent) / _radius
	_reversals = 0
	_last_sign = signf(_omega)
	player.air_dash_locked = false

func physics_update(delta: float) -> void:
	# Pendulum: gravity pulls the bob back toward hanging straight down.
	var alpha := -(player.movement.gravity / _radius) * sin(_theta)
	_omega += alpha * delta
	_theta += _omega * delta

	# Direction reversals are how the rope runs out of patience.
	var s := signf(_omega)
	if s != 0.0 and _last_sign != 0.0 and s != _last_sign:
		_reversals += 1
		if _reversals >= MAX_REVERSALS:
			_release()
			return
	if s != 0.0:
		_last_sign = s

	# Velocity is derived from the arc so move_and_slide carries the body — and
	# so a stomp landed mid-swing uses real velocity like any other stomp.
	var target := _anchor + Vector2(sin(_theta), cos(_theta)) * _radius
	player.velocity = (target - player.global_position) / delta

	if player.has_buffered_jump():
		player.consume_jump_buffer()
		player.velocity *= JUMP_BONUS
		machine.change_state(&"Air", {"anim": &"wall_jump"})
		return
	if player.wants_crouch():   # down lets go without the jump boost
		_release()
		return
	if player.is_on_floor() or player.is_on_wall():
		_release()

func _release() -> void:
	machine.change_state(&"Air")

func animation() -> StringName: return &"fall"
