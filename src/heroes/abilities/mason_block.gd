class_name MasonBlock extends Ability
## Mason — place a solid bumper block (DESIGN 5.2 #3). Max one alive at a time:
## placing a second replaces the first, so the block is a positioning statement
## rather than a wall of them.

@export var place_distance: float = 46.0
## Launch out of any face — above half a stage spring's, so bouncing off the
## block is a real launch rather than a nudge.
@export var bounce_speed: float = 620.0
## Long enough to be a piece of the fight, not a flicker: place it, then play
## around it for a while.
@export var block_lifetime: float = 6.5

var _placed: BumperBlock = null

func _execute(aim: Vector2) -> void:
	if _placed != null and is_instance_valid(_placed):
		_placed.queue_free()
	var block := BumperBlock.new()
	block.global_position = player.global_position + aim_or_facing(aim) * place_distance
	block.bounce_speed = bounce_speed
	block.lifetime = block_lifetime
	if player.hero != null:
		block.accent = player.hero.accent_color
	player.spawn_effect(block)
	_placed = block
