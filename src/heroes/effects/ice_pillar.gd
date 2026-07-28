class_name IcePillar extends TerrainElement
## Siku's ability block: a solid column of ice built bottom-up under her, with
## an icy cap, that melts after `lifetime`.
##
## The launch is NOT done here — it happens at cast time, before the collision
## exists, so nobody can be launched into the pillar they are standing in
## (SikuPillar._execute). This node is the terrain that is left behind.
##
## Melting shrinks the collision downward over MELT_TIME rather than freeing it
## outright. When a StaticBody2D vanishes from under a resting body, Godot's
## depenetration can fling that body ~100px (handoff.md); lowering the surface
## instead lets anyone standing on top ride it down and simply land.

## Everyone standing on the cap gets ice underfoot, same rule as the Ice
## element — asserted per tick, decayed by the player, so stepping off restores
## grip without this node noticing.
const CAP_SLIP: float = 1.0
const MELT_TIME: float = 0.45
## How long the visible build-up takes. Collision is complete from frame one:
## the cast already refused unless the whole column had room (SikuPillar), so
## there is nothing for a growing collider to catch on, and a body that fell
## into a half-built pillar would be exactly the bug the gate exists to stop.
const BUILD_TIME: float = 0.12

var pillar_size: Vector2 = Vector2(64.0, 80.0)
var lifetime: float = 5.0
var accent: Color = Color(0.62, 0.87, 1.0)

var _body: StaticBody2D
var _shape: CollisionShape2D
var _rect: RectangleShape2D
var _age: float = 0.0
var _melting: float = 0.0
## Bodies that were inside the column when it was built. The pillar's collision
## holds an exception for each until they have physically left it — without
## this the solid appears AROUND them and the physics server depenetrates them
## out the shortest way, which for a body at the base is straight down: Siku
## was being shoved into the floor (or through a thin platform) by her own
## cast, the exact bug the launch-first ordering alone could not prevent,
## because one frame of launch moves ~11px and the column is 80.
var _phasing_out: Array = []

func _ready() -> void:
	# The trigger covers the band a body OCCUPIES while standing on the cap, not
	# the cap line itself — same placement rule as an Ice sheet, which sits a
	# body-height above the surface it makes slippery.
	size = Vector2(pillar_size.x, 36.0)
	super()
	if _area != null:
		_area.position = Vector2(0.0, -18.0)

	_body = StaticBody2D.new()
	_body.collision_layer = 1    # terrain, like any wall
	_body.collision_mask = 0
	_rect = RectangleShape2D.new()
	_rect.size = pillar_size
	_shape = CollisionShape2D.new()
	_shape.shape = _rect
	# Origin is the TOP of the pillar, so shrinking the height downward keeps the
	# cap where it is until the very end and drops standers gently.
	_shape.position = Vector2(0.0, pillar_size.y * 0.5)
	_body.add_child(_shape)
	add_child(_body)
	for p in _phasing_out:
		if is_instance_valid(p):
			_body.add_collision_exception_with(p)

## Called by SikuPillar before the pillar enters the tree: everyone launched is
## also everyone the new collision must ignore until they are clear of it.
func ignore_until_clear(bodies: Array) -> void:
	_phasing_out = bodies.duplicate()

func physics_effect(p: Player, _delta: float) -> void:
	if p.is_on_floor():
		p.apply_surface_slip(CAP_SLIP)

func tick(delta: float) -> void:
	_age += delta
	_release_cleared_bodies()
	if _age < lifetime:
		queue_redraw()
		return
	# Melting: the cap sinks into the ground, taking standers down with it.
	_melting += delta
	var left: float = clampf(1.0 - _melting / MELT_TIME, 0.0, 1.0)
	var height := pillar_size.y * left
	_rect.size = Vector2(pillar_size.x, maxf(height, 1.0))
	_shape.position = Vector2(0.0, pillar_size.y - maxf(height, 1.0) * 0.5)
	if left <= 0.0:
		queue_free()
		return
	queue_redraw()

## A launched body becomes solid to the pillar again the moment it stops
## overlapping the column — usually at the top of its launch arc, so it lands
## back ON the cap. A body that never clears (frozen mid-column, wedged by a
## ceiling) keeps its exception for the pillar's life, which degrades to "the
## pillar is not solid to that one body" rather than to anyone stuck in ice.
func _release_cleared_bodies() -> void:
	for i in range(_phasing_out.size() - 1, -1, -1):
		var p := _phasing_out[i] as Player
		if p == null or not is_instance_valid(p):
			_phasing_out.remove_at(i)
			continue
		# Body AABB (22x34 about its centre) vs the column, with a small margin
		# so re-solidifying never happens while still in contact.
		var column := Rect2(global_position + Vector2(-pillar_size.x * 0.5, 0.0), pillar_size)
		var body_box := Rect2(p.global_position - Vector2(12.0, 18.0), Vector2(24.0, 36.0))
		if not column.intersects(body_box):
			_body.remove_collision_exception_with(p)
			_phasing_out.remove_at(i)

func _draw() -> void:
	var grow: float = clampf(_age / BUILD_TIME, 0.0, 1.0)
	var left: float = clampf(1.0 - _melting / MELT_TIME, 0.0, 1.0)
	var height := pillar_size.y * grow * left
	if height <= 0.0:
		return
	# Drawn from the bottom up while building, and sinking while melting.
	var top := pillar_size.y - height
	var body_rect := Rect2(Vector2(-pillar_size.x * 0.5, top),
		Vector2(pillar_size.x, height))
	draw_rect(body_rect, Color(0.35, 0.62, 0.78, 0.55))
	draw_rect(body_rect, Color(accent.r, accent.g, accent.b, 0.85), false, 2.0)
	# Vertical facets, so a big block of ice does not read as a flat slab.
	for i in 3:
		var x := -pillar_size.x * 0.5 + pillar_size.x * (float(i) + 1.0) / 4.0
		draw_line(Vector2(x, top + 3.0), Vector2(x, top + height - 3.0),
			Color(1, 1, 1, 0.18), 1.0)
	# Lit cap: this is the surface people stand on, so it has to read as one.
	draw_rect(Rect2(Vector2(-pillar_size.x * 0.5, top), Vector2(pillar_size.x, 3.0)),
		Color(0.85, 0.98, 1.0, 0.95))
