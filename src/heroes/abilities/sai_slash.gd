class_name SaiSlash extends Ability
## Sai's ultimate (DESIGN 5.2): cross a long straight line instantly, through
## bodies AND through terrain — platforms, floors, and walls do not stop the
## cut. Everyone he passes is slowed and has their jump, dash, and wall jump
## gutted for a window — hit by the slash, you still move, but you stop being a
## platform fighter for a few seconds.
##
## Passing through terrain means the endpoint has to be chosen, not just taken:
## the raw end of the line can sit inside a wall, or past the sealed boundary in
## the void. _resolve_destination walks back along the line until it finds a spot
## where the body actually fits inside the arena, so the slash can never leave
## Sai buried or out of bounds.

@export var distance: float = 600.0
## Half-width of the cut. Widened by half a character height each side, so the
## whole corridor grew by about one body — the slash is an ultimate, and dodging
## it should take a real move, not a crouch.
@export var corridor: float = 52.0
@export var slow_mult: float = 0.415
@export var impair_mult: float = 0.3
@export var debuff_time: float = 10.0

## Endpoint search: how far apart the candidate landing spots are.
const RESOLVE_STEP: float = 12.0
## Body clearance box — a shade inside the real 22x34 body so a landing flush
## against a surface is not refused over a contact margin.
const CLEARANCE: Vector2 = Vector2(20.0, 30.0)
## How far the enclosure test looks for the sealed box around a candidate.
const ENCLOSURE_REACH: float = 4000.0

func _execute(aim: Vector2) -> void:
	var dir := aim_or_facing(aim)
	var from := player.global_position
	var to := _resolve_destination(from, dir)

	for t in enemies_of(player):
		var victim := t as Player
		var offset := victim.global_position - from
		var along := clampf(offset.dot(dir), 0.0, from.distance_to(to))
		if (offset - dir * along).length() > corridor:
			continue
		victim.apply_slow(slow_mult, debuff_time, &"slash")
		victim.apply_impairment(impair_mult, debuff_time, &"slash")

	var trail := SlashTrail.new()
	trail.from_point = from
	trail.to_point = to
	if player.hero != null:
		trail.accent = player.hero.accent_color
	player.spawn_effect(trail)
	player.global_position = to
	player.set_velocity_override(dir * 260.0)

## The furthest point along the line where the body fits in open space AND is
## still inside the sealed arena. Walked from the far end back toward Sai, so
## the slash always travels as far as it safely can.
func _resolve_destination(from: Vector2, dir: Vector2) -> Vector2:
	var space := player.get_world_2d().direct_space_state
	var travelled := distance
	while travelled > 0.0:
		var candidate := from + dir * travelled
		if _fits(space, candidate) and _enclosed(space, candidate):
			return candidate
		travelled -= RESOLVE_STEP
	return from  # every spot along the line is buried: cut in place, go nowhere

## Body-sized clearance check against terrain.
func _fits(space: PhysicsDirectSpaceState2D, at: Vector2) -> bool:
	var rect := RectangleShape2D.new()
	rect.size = CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()

## Inside the sealed box, terrain exists both above and below every open point
## (the box has a floor and a ceiling by construction — DESIGN 6.1). Outside it
## — past a side wall, above the roof — at least one of those rays finds
## nothing, which is how the slash knows it has cut through the boundary rather
## than through a platform.
func _enclosed(space: PhysicsDirectSpaceState2D, at: Vector2) -> bool:
	for vertical: Vector2 in [Vector2.DOWN, Vector2.UP]:
		var query := PhysicsRayQueryParameters2D.create(at, at + vertical * ENCLOSURE_REACH)
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			return false
	return true
