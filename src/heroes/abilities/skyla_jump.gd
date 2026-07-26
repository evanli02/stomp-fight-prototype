class_name SkylaJump extends Ability
## Skyla — a second jump in mid-air, STRONGER than a normal one (DESIGN 5.2 #2).
##
## Not aimed and not a redirect: horizontal momentum is left exactly as it was.
## The jump button goes up, and direction stays with the stick you are already
## steering with. What the ability buys is height you cannot otherwise reach.

## Above a full-hold jump (~72px) on purpose — this clears geometry a normal
## jump cannot, which is the whole reason to spend a cooldown on it.
@export var impulse: float = -560.0

func _execute(_aim: Vector2) -> void:
	player.air_dash_locked = false
	# Fixed height, not hold-extendable: it is already stronger than a real jump.
	player.request_state(&"Air", {
		"jump": true,
		"impulse_y": impulse,
		"extendable": false,
		"anim": &"cast",
	})
