class_name MasonBlock extends Ability
## Mason — place a bounce block; ALL players ricochet off it (DESIGN 5.2 #3).
## Max 1 alive; placing another frees the old. Block is a TerrainElement scene.
## Ultimate (Keystone): block knocks back + stuns enemies (combat.stun_mason_ult_block),
## buffs allies passing through (+15% speed 4 s) via grant_speed_buff().

func _execute(aim: Vector2) -> void:
	pass # TODO(M4): place block scene at aimed position (range-clamped)
