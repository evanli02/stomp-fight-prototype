class_name CerebelleBurst extends Ability
## Cerebelle — radial knockback with NO stun (DESIGN 5.2 #4). Pure displacement, and
## a lot of it: it breaks a stomp setup apart or throws someone clean off a
## rooftop, without ever buying Cerebelle a free stomp of her own.

## Wide: the burst is her whole defensive answer, and a radius you can stand
## just outside of while lining up a stomp was not answering anything.
@export var radius: float = 210.0
@export var force: float = 980.0

func _execute(_aim: Vector2) -> void:
	var burst := RadialBurst.new()
	player.spawn_effect(burst)
	var colour: Color = player.hero.accent_color if player.hero != null else Color.WHITE
	burst.detonate(player.global_position, enemies_of(player), radius, force, 0.0, colour)
