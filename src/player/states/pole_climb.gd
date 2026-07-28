class_name PoleClimbState extends PlayerState
## Hanging on a pole (DESIGN 6.2). Momentum is gone the instant you grab: this is
## the one state in the whole kit that throws speed away on purpose, and what it
## buys is total control — you pick your height, then pick your exit.
##
## Four ways out, checked in this order:
##   down + jump   let go, keeping whatever you were already doing
##   jump          leap off to whichever side the movement stick holds
##   dash          boosted drop straight down, spends a charge
##   ride off      slide or climb past either end
##
## Down on its own no longer lets go — it rides the pole down fast. A pole is
## vertical ground, and the useful thing to do with vertical ground is travel it;
## before this, the only quick way down was to let go and fall, which threw away
## the pole's whole point. Letting go is still one button away, it just needs
## saying rather than happening by default.

## Riding down. Much faster than the climb, because descending a pole you already
## own should not be slower than falling past it.
const SLIDE_SPEED: float = 480.0

var _pole_x: float = 0.0
var _climb_speed: float = 140.0
var _jump_off: Vector2 = Vector2(280, -420)
var _top: float = 0.0
var _bottom: float = 0.0

func enter(params: Dictionary = {}) -> void:
	_pole_x = params.get("pole_x", player.global_position.x)
	_climb_speed = params.get("climb_speed", 140.0)
	_jump_off = params.get("jump_off", Vector2(280, -420))
	_top = params.get("top", -INF)
	_bottom = params.get("bottom", INF)
	# The grab itself is the reset (DESIGN 6.2).
	player.velocity = Vector2.ZERO
	player.momentum_charge = 0.0
	player.air_dash_locked = false
	player.dash_charges_left = player.movement.dash_charges
	player.global_position.x = _pole_x

func physics_update(_delta: float) -> void:
	if player.has_buffered_jump():
		player.consume_jump_buffer()
		if player.wants_crouch():
			machine.change_state(&"Air")   # let go, carrying the ride
		else:
			_leap()
		return
	if player.input.dash_pressed and player.can_dash():
		_drop_dash()
		return

	player.global_position.x = _pole_x
	# A full down press rides; a light one still crawls, so the analog stick keeps
	# the fine control the pole exists to give.
	if player.wants_crouch():
		player.velocity = Vector2(0.0, SLIDE_SPEED)
	else:
		player.velocity = Vector2(0.0, player.input.move.y * _climb_speed)

	if player.global_position.y < _top or player.global_position.y > _bottom:
		machine.change_state(&"Air")
		return
	if player.is_on_floor() and player.input.move.y > 0.0:
		machine.change_state(&"Idle")

## Off to whichever side is being held; neutral leaves the way you were facing.
func _leap() -> void:
	var side := signf(player.input.move.x)
	if is_zero_approx(side):
		side = float(player.facing)
	player.velocity = Vector2(_jump_off.x * side, _jump_off.y)
	player.facing = 1 if side > 0.0 else -1
	machine.change_state(&"Air", {"anim": &"wall_jump"})

## Dash straight down off the pole: terminal velocity immediately instead of the
## quarter-second and two hundred pixels it takes to accelerate there. Aimed at
## the head of anyone below, and it resolves as an ordinary stomp if it lands on
## one — a fast fall is exactly what the stomp system already reads.
##
## Uses fall_speed_max rather than a number of its own, because anything above it
## is clamped away by Air on the very next frame.
func _drop_dash() -> void:
	player.consume_dash_charge()
	player.air_dash_locked = true
	player.velocity = Vector2(0.0, player.movement.fall_speed_max)
	machine.change_state(&"Air")

func animation() -> StringName: return &"pole_climb"
