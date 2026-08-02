class_name FractureWave extends Node2D
## Terra's ultimate (DESIGN 5.2): an instantaneous wall of force along the aim —
## the same shape of thing as Kid's wind cannon, but much wider, and it does NOT
## pass through terrain: the wave crosses the stage in one frame and dies on the
## first surface it meets. Bodies never stop it; only the stage does.
##
## Everyone caught in the corridor is stunned and hurled toward the surface the
## wave stopped at. The hurl is a velocity override, not a teleport — the body
## flies there under move_and_slide, so it lands pinned against whatever is
## actually in its own path and can never be pushed inside terrain. They arrive
## slowed and with jump/dash gutted for a long window: grounded, in both senses.
## It cannot take a life (CLAUDE.md 1).

## Wider than Kid's cannon (44) by a lot: this is the ultimate version of the
## shape, and dodging it should mean not being in the half of the stage it
## crossed, not stepping one body-width aside.
var half_width: float = 90.0
## Longer than any stage dimension — in a sealed arena the wave always ends on
## terrain, which is the point: there is always a wall to be thrown against.
const MAX_RANGE: float = 2400.0
## The hurl. Fast enough that "instantly pushed to the wall" is what it looks
## like — most of the stage is crossed inside a couple of tenths of a second —
## while still being real velocity that terrain resolves honestly.
var push_speed: float = 2600.0
var slow_mult: float = 0.805
var slow_time: float = 11.0
var impair_time: float = 8.5
const LIFE: float = 0.45

var accent: Color = Color(0.71, 0.40, 0.11)
var from_point: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var _reach: float = 0.0
var _age: float = 0.0

func launch(caster: Player, dir: Vector2) -> void:
	from_point = caster.global_position
	direction = dir.normalized()
	global_position = from_point
	if caster.hero != null:
		accent = caster.hero.accent_color

	# Where the wave stops: the first terrain along the centre line.
	var space := caster.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		from_point, from_point + direction * MAX_RANGE)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	_reach = from_point.distance_to(hit.position) if not hit.is_empty() else MAX_RANGE

	# Resolved once, on spawn, like the wind cannon: instantaneous is the design,
	# so there is no travel window to dodge inside. Sorted for determinism.
	var targets := caster.get_tree().get_nodes_in_group(&"players")
	targets.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	for t in targets:
		var p := t as Player
		if p == null or p.team_id == caster.team_id:
			continue
		var offset := p.global_position - from_point
		var along := offset.dot(direction)
		if along < 0.0 or along > _reach:
			continue
		if (offset - direction * along).length() > half_width:
			continue
		p.apply_stun(caster.combat.stun_terra_ult)
		# The stun keeps momentum by design, which is exactly what carries them
		# the rest of the way to the wall.
		p.set_velocity_override(direction * push_speed)
		p.apply_slow(slow_mult, slow_time, &"fracture")
		p.apply_impairment(0.0, impair_time, &"fracture")

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / LIFE, 0.0, 1.0)
	var dir := direction
	var n := Vector2(-dir.y, dir.x)
	# The corridor: a translucent slab from Terra to the wall it broke on.
	var corners: PackedVector2Array = [
		n * half_width, dir * _reach + n * half_width,
		dir * _reach - n * half_width, -n * half_width,
	]
	draw_colored_polygon(corners, Color(accent.r, accent.g, accent.b, fade * 0.28))
	for lane: float in [-1.0, 1.0]:
		draw_line(n * lane * half_width, dir * _reach + n * lane * half_width,
			Color(accent.r, accent.g, accent.b, fade * 0.9), 2.5)
	# Cross-ripples sweeping toward the impact, selling the direction.
	for i in 5:
		var at := dir * minf(60.0 + i * (_reach / 5.0) + _age * 1600.0, _reach)
		draw_line(at - n * half_width, at + n * half_width, Color(1, 1, 1, fade * 0.35), 1.5)
	# The impact face: the wall the wave (and everyone in it) stopped at.
	draw_line(dir * _reach - n * half_width, dir * _reach + n * half_width,
		Color(1, 1, 1, fade), 4.0)
