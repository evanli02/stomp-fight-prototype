class_name SkylaDoubleTrouble extends Ability
## Skyla's ultimate — Double Trouble: the ability may be used twice in a row for
## a window (DESIGN 5.2 #2). One extra cooldown-free use, not infinite ones.

@export var duration: float = 8.0
@export var extra_uses: int = 1

func _execute(_aim: Vector2) -> void:
	var basic := player.equipped_ability()
	if basic != null:
		basic.grant_waiver(duration, extra_uses)
