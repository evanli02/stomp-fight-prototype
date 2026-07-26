class_name KidEmp extends Ability
## Kid's ultimate (DESIGN 5.2): the EMP. A telegraphed beat of charge-up, then
## every enemy on the stage is slowed and locked out of dash, ability, and
## ultimate for the window. It touches no one's position and no one's lives —
## it just turns the tech off.

func _execute(_aim: Vector2) -> void:
	var wave := EmpWave.new()
	player.spawn_effect(wave)
	wave.charge(player)
