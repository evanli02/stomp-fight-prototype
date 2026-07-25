class_name DeadeyeBolt extends Ability
## Deadeye — aim & fire a stun bolt (DESIGN 5.2 #1). On hit: enemy stunned
## combat.stun_deadeye_bolt. Ultimate (Rapid Fire) reuses this with free-fire
## flag for 5 s. Bolt is a projectile scene; it calls target.apply_stun() only.

func _execute(aim: Vector2) -> void:
	pass # TODO(M4): spawn bolt projectile scene along `aim`
