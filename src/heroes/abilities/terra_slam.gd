class_name TerraSlam extends Ability
## Terra — the slam (DESIGN 5.2). Air only: hang for a beat, then drive straight
## down. Landing throws a shockwave that shoves and briefly stuns.
##
## The famous part needs no special rule: a slam is a very fast fall, and
## falling onto a head IS a stomp. The plummet resolves through the ordinary
## stomp system — victim authority, grace, anti-chain — so the slam kill is a
## stomp kill, and CLAUDE.md rule 1 stands untouched.

func _can_fire() -> bool:
	return not player.is_on_floor()   # refused on the ground, nothing spent

func _execute(_aim: Vector2) -> void:
	player.request_state(&"Slam")
