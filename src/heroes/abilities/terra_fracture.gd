class_name TerraFracture extends Ability
## Terra's ultimate (DESIGN 5.2): the fracture slab. Fires along the aim, drags
## whoever it catches, detonates on terrain — the caught drop to the floor
## slowed and unable to dash or jump for a beat.

func _execute(aim: Vector2) -> void:
	var shot := FractureShot.new()
	player.spawn_effect(shot)
	shot.launch(player, aim_or_facing(aim))
