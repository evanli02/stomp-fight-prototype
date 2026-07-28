class_name CerebelleSupernova extends Ability
## Cerebelle's ultimate — Supernova (DESIGN 5.2 #4): a single ring leaving her body
## and expanding until it has crossed the whole stage.
##
## Slow enough to outrun, wide enough that outrunning it only buys time. Whoever
## it catches is stunned, stripped of all momentum, and dropped.

## Still well under a capped run (420) so reacting early actually works — just
## less room to be casual about it.
@export var ring_speed: float = 250.0
## Generous enough to sweep the largest stage from any corner.
@export var reach: float = 1800.0

func _execute(_aim: Vector2) -> void:
	var ring := ShockwaveRing.new()
	player.spawn_effect(ring)
	ring.launch(player, ring_speed, reach, player.combat.stun_nova_ult)
