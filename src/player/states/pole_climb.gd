class_name PoleClimbState extends PlayerState
## Hanging on a pole (DESIGN 6.2). Momentum is gone the instant you grab: this is
## the one state in the whole kit that throws speed away on purpose, and what it
## buys is total control — you pick your height, then pick your exit.
##
## Leaving: jump off either side (the movement stick chooses which), drop off by
## holding down, or climb past either end.

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
		_leap()
		return
	# Down drops off rather than climbing below the pole.
	if player.wants_crouch():
		machine.change_state(&"Air")
		return

	player.global_position.x = _pole_x
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

func animation() -> StringName: return &"pole_climb"
