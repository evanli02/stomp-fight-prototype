class_name SkylaJump extends Ability
## Skyla — double jump with FULL momentum redirect at activation (DESIGN 5.2 #2).
## Implemented as player.request_state(&"Air", {redirect: aim, impulse: jump}).
## Ultimate (Double Trouble): ability usable twice in a row for 8 s.

func _execute(aim: Vector2) -> void:
	pass # TODO(M4)
