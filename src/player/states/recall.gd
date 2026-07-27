class_name RecallState extends PlayerState
## Slip's rewind (DESIGN 5.2): an instant return to the anchor she dropped.
##
## This used to replay the exact path travelled since the anchor was placed, so
## the return would be visible and chaseable. It was not worth what it cost — a
## recorded path drifts out of sync with anything that moves the body for you
## (terrain, knockback, another rewind), and a rewind that visibly misses its own
## anchor is worse than one you cannot contest. A blink is honest about what the
## ability does.
##
## The tradeoff taken on purpose: a blink does not verify the route, so the
## anchor point itself is the only thing that has to be reachable. Godot's
## depenetration handles arriving inside something; the brief hold below is what
## gives it a frame to do that before normal movement resumes.

const BLINK_TIME: float = 0.08

var _left: float = 0.0

func enter(params: Dictionary = {}) -> void:
	var target: Vector2 = params.get("to", player.global_position)
	_left = BLINK_TIME
	player.air_dash_locked = false
	player.velocity = Vector2.ZERO
	player.global_position = target

func physics_update(delta: float) -> void:
	# No gravity during the blink: a frame of fall before the body has settled
	# reads as the arrival sagging, which makes the teleport look imprecise.
	player.velocity = Vector2.ZERO
	_left -= delta
	if _left <= 0.0:
		machine.change_state(&"Air")

func animation() -> StringName: return &"dash"
