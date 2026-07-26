class_name SkylaJump extends Ability
## Skyla — a second jump that FULLY redirects momentum at activation
## (DESIGN 5.2 #2). The redirect is the point: an ordinary double jump adds
## height, this one lets you leave in a direction you were not going, which is
## how a speedster escapes a stomp setup.

@export var impulse: float = 430.0
## Below this the stick is treated as neutral and the jump goes straight up,
## rather than being redirected somewhere the player did not choose.
@export var redirect_deadzone: float = 0.3

func _execute(_aim: Vector2) -> void:
	var steer := player.input.move
	var dir := steer.normalized() if steer.length() > redirect_deadzone else Vector2.UP
	# Replace, never add: this is a redirect, and adding would let Skyla stack
	# her own momentum into something no other hero can reach.
	player.set_velocity_override(dir * impulse)
	player.air_dash_locked = false
	player.request_state(&"Air", {"jump": true, "impulse_y": player.velocity.y,
		"extendable": false, "anim": &"cast"})
