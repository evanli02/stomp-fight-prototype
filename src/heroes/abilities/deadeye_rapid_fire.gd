class_name DeadeyeRapidFire extends Ability
## Deadeye's ultimate — Rapid Fire: free-fire stun bolts for a window
## (DESIGN 5.2 #1). Implemented as a cooldown waiver on the basic ability rather
## than as its own firing loop, so there is exactly one place that knows how a
## bolt is made.

@export var duration: float = 5.0
## Effectively unlimited within the window; the fire rate is the player's thumb.
@export var uses: int = 99

func _execute(_aim: Vector2) -> void:
	var basic := player.equipped_ability()
	if basic != null:
		basic.grant_waiver(duration, uses)
