class_name NovaSupernova extends Ability
## Nova's ultimate — Supernova (DESIGN 5.2 #4): a much larger burst that also
## stuns every enemy it catches for combat.stun_nova_ult. The stun is what makes
## it a team-wide setup rather than just a shove.

@export var radius: float = 240.0
@export var force: float = 620.0

func _execute(_aim: Vector2) -> void:
	var burst := RadialBurst.new()
	player.spawn_effect(burst)
	var colour: Color = player.hero.accent_color if player.hero != null else Color.WHITE
	burst.detonate(player.global_position, enemies_of(player), radius, force,
		player.combat.stun_nova_ult, colour)
