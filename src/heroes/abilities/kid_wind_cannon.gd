class_name KidWindCannon extends Ability
## Kid — the wind cannon (DESIGN 5.2): a stage-crossing column of air along the
## aim, straight through terrain, shoving everyone in it — allies included.
## Wind does not check team colours; aiming it well is the skill.

## Half-width of the column. Everyone inside it is shoved, allies included.
@export var width: float = 44.0
## The shove, in px/s. Applied once, the instant it fires.
@export var push: float = 1000.0

func _execute(aim: Vector2) -> void:
	var beam := WindBeam.new()
	beam.width = width
	beam.push = push
	player.spawn_effect(beam)
	beam.blow(player, aim_or_facing(aim))
