class_name NovaBurst extends Ability
## Nova — radial burst that knocks nearby enemies back with NO stun
## (DESIGN 5.2 #4). Pure displacement: it breaks up a stomp setup or shoves
## someone off a rooftop edge into open air, and never buys a free stomp itself.

@export var radius: float = 110.0
@export var force: float = 460.0

func _execute(_aim: Vector2) -> void:
	var burst := RadialBurst.new()
	player.spawn_effect(burst)
	var colour: Color = player.hero.accent_color if player.hero != null else Color.WHITE
	burst.detonate(player.global_position, enemies_of(player), radius, force, 0.0, colour)
