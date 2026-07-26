class_name SkylaJump extends Ability
## Skyla — a second jump in mid-air (DESIGN 5.2 #2).
##
## Deliberately NOT aimed and NOT a redirect. It is a plain extra jump, weaker
## than a real one, and it leaves horizontal momentum alone: whatever you were
## carrying, you keep. The aimed redirect it replaced fought the player — the
## jump button should go up, and direction should stay with the stick you are
## already steering with.

## Weaker than the minimum hop, so the second jump extends an arc instead of
## restarting it.
@export var impulse: float = -230.0

func _execute(_aim: Vector2) -> void:
	player.air_dash_locked = false
	# Not hold-extendable: a held second jump would out-climb the first.
	player.request_state(&"Air", {
		"jump": true,
		"impulse_y": impulse,
		"extendable": false,
		"anim": &"cast",
	})
