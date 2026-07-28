class_name FeiJump extends Ability
## Fei — a second jump in mid-air, STRONGER than a normal one (DESIGN 5.2 #2).
##
## Not aimed and not a redirect: horizontal momentum is left exactly as it was.
## The jump button goes up, and direction stays with the stick you are already
## steering with. What the ability buys is height you cannot otherwise reach.

## Above a full-hold jump (~72px) on purpose — this clears geometry a normal
## jump cannot, which is the whole reason to spend a cooldown on it.
@export var impulse: float = -560.0

func _execute(_aim: Vector2) -> void:
	player.air_dash_locked = false
	# The cloud she kicks off: pure visual, drawn at the point in the air the
	# jump happened, so the wind she summoned is a place you can see.
	var puff := WindPuff.new()
	puff.global_position = player.global_position + Vector2(0.0, 14.0)
	if player.hero != null:
		puff.accent = player.hero.accent_color
	player.spawn_effect(puff)
	# Fixed height, not hold-extendable: it is already stronger than a real jump.
	player.request_state(&"Air", {
		"jump": true,
		"impulse_y": impulse,
		"extendable": false,
		"anim": &"cast",
	})
