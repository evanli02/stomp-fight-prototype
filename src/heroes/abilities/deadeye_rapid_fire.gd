class_name DeadeyeRapidFire extends Ability
## Deadeye's ultimate (DESIGN 5.2 #1): refunds the bolt cooldown and loads the
## NEXT bolt as a heavy one — faster, and a stun long enough to be a guaranteed
## setup rather than a nudge.
##
## One shot, not a window. It rewards picking the moment instead of spraying.

@export var speed_mult: float = 1.5
@export var empowered_stun: float = 4.0

func _execute(_aim: Vector2) -> void:
	var basic := player.equipped_ability()
	if basic == null:
		return
	basic.reset_cooldown()
	if basic is DeadeyeBolt:
		(basic as DeadeyeBolt).load_empowered_shot(speed_mult, empowered_stun)
