class_name RadialBurst extends Node2D
## The shared shape of Nova's ability and ultimate: everything inside a radius
## gets pushed away from the centre, and optionally stunned.
##
## Resolved once on spawn rather than over the ring's lifetime — the visual is
## just a visual, so a player cannot dodge by being fast, and the result does not
## depend on when anyone's frame happened to land.

## Near-instant: the hit already resolves on spawn, so a slow ring made the
## ability look laggy when it was not.
const FADE: float = 0.1

var radius: float = 110.0
var force: float = 460.0
var stun_time: float = 0.0
var accent: Color = Color(0.62, 0.31, 0.87)

var _age: float = 0.0

## `targets` is pre-filtered by the caller so this scene never has to know what
## counts as an enemy.
func detonate(at: Vector2, targets: Array, burst_radius: float,
		burst_force: float, stun: float, colour: Color) -> void:
	global_position = at
	radius = burst_radius
	force = burst_force
	stun_time = stun
	accent = colour
	for t in targets:
		var victim := t as Player
		if victim == null:
			continue
		var offset := victim.global_position - at
		if offset.length() > radius:
			continue
		# Straight up for a target standing exactly on the centre, so the push is
		# never a zero vector.
		var dir := offset.normalized() if offset.length() > 1.0 else Vector2.UP
		# Falls off with distance: standing on top of it should hurt most.
		var scale := 1.0 - (offset.length() / radius) * 0.5
		victim.apply_impulse(dir * force * scale)
		if stun_time > 0.0:
			victim.apply_stun(stun_time)

func _process(delta: float) -> void:
	_age += delta
	if _age >= FADE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clampf(_age / FADE, 0.0, 1.0)
	var r := radius * (0.35 + 0.65 * t)
	var col := Color(accent.r, accent.g, accent.b, 1.0 - t)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, 3.0)
	draw_arc(Vector2.ZERO, r * 0.75, 0.0, TAU, 32, Color(1, 1, 1, (1.0 - t) * 0.5), 1.5)
