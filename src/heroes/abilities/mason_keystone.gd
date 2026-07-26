class_name MasonKeystone extends Ability
## Mason's ultimate — Keystone (DESIGN 5.2 #3): the same block, but enemies
## passing through are knocked back and stunned while allies get a speed buff.
## It never removes a life; it decides who owns a lane.

@export var place_distance: float = 46.0
@export var bounce_force: float = 620.0
@export var block_lifetime: float = 10.0
@export var buff_mult: float = 1.15
@export var buff_time: float = 4.0

func _execute(aim: Vector2) -> void:
	var block := BounceBlock.new()
	block.global_position = player.global_position + aim_or_facing(aim) * place_distance
	block.bounce_force = bounce_force
	block.lifetime = block_lifetime
	block.is_keystone = true
	block.owner_team = player.team_id
	block.stun_time = player.combat.stun_mason_ult_block
	block.buff_mult = buff_mult
	block.buff_time = buff_time
	if player.hero != null:
		block.accent = player.hero.accent_color
	player.spawn_effect(block)
