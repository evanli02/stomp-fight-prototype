class_name MasonBlock extends Ability
## Mason — place a solid bumper block (DESIGN 5.2 #3). Max one alive at a time:
## placing a second replaces the first, so the block is a positioning statement
## rather than a wall of them.

@export var place_distance: float = 46.0
@export var elasticity: float = 1.15
@export var min_bounce: float = 320.0
@export var block_lifetime: float = 4.0

var _placed: BumperBlock = null

func _execute(aim: Vector2) -> void:
	if _placed != null and is_instance_valid(_placed):
		_placed.queue_free()
	var block := BumperBlock.new()
	block.global_position = player.global_position + aim_or_facing(aim) * place_distance
	block.elasticity = elasticity
	block.min_bounce = min_bounce
	block.lifetime = block_lifetime
	if player.hero != null:
		block.accent = player.hero.accent_color
	player.spawn_effect(block)
	_placed = block
