class_name NovaBurst extends Ability
## Nova — radial knockback with NO stun (DESIGN 5.2 #4). Pure displacement, and
## a lot of it: it breaks a stomp setup apart or throws someone clean off a
## rooftop, without ever buying Nova a free stomp of his own.

@export var radius: float = 165.0
@export var force: float = 980.0

func _execute(_aim: Vector2) -> void:
	var burst := RadialBurst.new()
	player.spawn_effect(burst)
	var colour: Color = player.hero.accent_color if player.hero != null else Color.WHITE
	burst.detonate(player.global_position, enemies_of(player), radius, force, 0.0, colour)
