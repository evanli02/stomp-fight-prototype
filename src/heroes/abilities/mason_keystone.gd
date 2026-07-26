class_name MasonKeystone extends Ability
## Mason's ultimate — Keystone (DESIGN 5.2 #3): a block his own team walks
## through and enemies do not. An enemy who touches it is frozen and stunned,
## then dropped under normal gravity when it wears off. No life, ever.

@export var place_distance: float = 46.0
@export var block_lifetime: float = 10.0

func _execute(aim: Vector2) -> void:
	var block := FreezeBlock.new()
	block.global_position = player.global_position + aim_or_facing(aim) * place_distance
	block.lifetime = block_lifetime
	block.owner_team = player.team_id
	block.freeze_time = player.combat.stun_mason_ult_block
	if player.hero != null:
		block.accent = player.hero.accent_color
	player.spawn_effect(block)
