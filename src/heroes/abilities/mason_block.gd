class_name MasonBlock extends Ability
## Mason — place a bounce block everyone ricochets off (DESIGN 5.2 #3).
## Max one alive at a time: placing a second replaces the first, so the block is
## a positioning statement rather than a wall of them.

@export var place_distance: float = 46.0
@export var bounce_force: float = 520.0
@export var block_lifetime: float = 8.0

var _placed: BounceBlock = null

func _execute(aim: Vector2) -> void:
	if _placed != null and is_instance_valid(_placed):
		_placed.queue_free()
	var block := BounceBlock.new()
	block.global_position = player.global_position + aim_or_facing(aim) * place_distance
	block.bounce_force = bounce_force
	block.lifetime = block_lifetime
	block.owner_team = player.team_id
	if player.hero != null:
		block.accent = player.hero.accent_color
	player.spawn_effect(block)
	_placed = block
