class_name DeadeyeBolt extends Ability
## Deadeye — aim and fire a stun bolt (DESIGN 5.2 #1). On hit the enemy is
## stunned for combat.stun_deadeye_bolt. No knockback, no life: the value is
## that a stunned player is a stompable player, which is the whole setup game.

@export var bolt_speed: float = 620.0

func _execute(aim: Vector2) -> void:
	var bolt := StunBolt.new()
	bolt.global_position = player.global_position
	bolt.launch(player, aim_or_facing(aim), player.combat.stun_deadeye_bolt, bolt_speed)
	player.spawn_effect(bolt)
