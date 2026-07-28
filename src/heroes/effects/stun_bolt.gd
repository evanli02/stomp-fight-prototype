class_name StunBolt extends BoltProjectile
## Deadeye's projectile: the shared bolt flight (BoltProjectile) with a stun for
## a payload. It applies a stun and nothing else — the value is that a stunned
## player is a stompable player, which is the whole setup game.

var stun_time: float = 0.8
## Deadeye's ultimate shot: drawn heavier so the loaded bolt is legible, and it
## is the variant that flies through walls (`piercing`, set by the ability).
var empowered: bool = false

func _on_hit(victim: Player) -> void:
	victim.apply_stun(stun_time)

func _draw() -> void:
	var length := LENGTH * (1.6 if empowered else 1.0)
	var thick := THICKNESS * (1.8 if empowered else 1.0)
	if empowered:
		draw_rect(Rect2(-length * 0.5 - 3.0, -thick * 0.5 - 1.0,
			length + 6.0, thick + 2.0), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(-length * 0.5, -thick * 0.5, length, thick), accent)
	draw_rect(Rect2(length * 0.5 - 2.0, -thick * 0.5, 2.0, thick), Color.WHITE)
