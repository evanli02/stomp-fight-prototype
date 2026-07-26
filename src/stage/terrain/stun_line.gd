class_name StunLine extends TerrainElement
## Glowing tripwire (DESIGN 6.2): touching it stuns, momentum is kept, and the
## head hurtbox stays ACTIVE. That last part is the whole point — a stun line is
## the classic stomp setup, not a safe zone.

@export var retrigger: float = 0.8
var _cooldown: Dictionary = {}

func tick(delta: float) -> void:
	for id in _cooldown.keys():
		_cooldown[id] -= delta
		if _cooldown[id] <= 0.0:
			_cooldown.erase(id)
	queue_redraw()

func on_body_entered(p: Player) -> void:
	var id := p.get_instance_id()
	if _cooldown.has(id):
		return
	_cooldown[id] = retrigger
	# Stun only. Never a life, never knockback (CLAUDE.md 1).
	p.apply_stun(p.combat.stun_line)

func _draw() -> void:
	var half := size * 0.5
	var pulse: float = 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.006)
	draw_rect(Rect2(-half, size), Color(1.0, 0.82, 0.25, 0.22 * pulse))
	draw_rect(Rect2(Vector2(-half.x, -1), Vector2(size.x, 2)),
		Color(1.0, 0.82, 0.25, pulse))
	for i in int(size.x / 8.0):
		draw_rect(Rect2(-half + Vector2(i * 8, -3), Vector2(2, 6)),
			Color(1.0, 0.95, 0.69, pulse))
