class_name KidWindCannon extends Ability
## Kid — the wind cannon (DESIGN 5.2): a stage-crossing column of air along the
## aim, straight through terrain, shoving everyone in it — allies included.
## Wind does not check team colours; aiming it well is the skill.

func _execute(aim: Vector2) -> void:
	var beam := WindBeam.new()
	player.spawn_effect(beam)
	beam.blow(player, aim_or_facing(aim))
