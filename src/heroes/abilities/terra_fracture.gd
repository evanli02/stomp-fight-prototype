class_name TerraFracture extends Ability
## Terra's ultimate (DESIGN 5.2): the fracture wave. An instantaneous, very wide
## wall of force along the aim that stops at the first terrain it meets — every
## enemy in the corridor is stunned, hurled against that surface, and left
## slowed with jump and dash gutted for a long beat. The old version was a slab
## that travelled and dragged; the rework trades the travel for width and
## immediacy.

func _execute(aim: Vector2) -> void:
	var wave := FractureWave.new()
	player.spawn_effect(wave)
	wave.launch(player, aim_or_facing(aim))
