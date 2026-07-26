class_name SkylaDoubleTrouble extends Ability
## Skyla's ultimate (DESIGN 5.2 #2): for a window, her jump comes back almost
## immediately. Not free — a 1s cooldown still paces it — but close enough to
## chain jumps across the whole stage.

@export var duration: float = 7.0
@export var reduced_cooldown: float = 1.0

func _execute(_aim: Vector2) -> void:
	var basic := player.equipped_ability()
	if basic != null:
		basic.grant_cooldown_override(reduced_cooldown, duration)
		basic.reset_cooldown()   # the window starts now, not after the current wait
