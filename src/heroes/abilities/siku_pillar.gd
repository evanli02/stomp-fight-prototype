class_name SikuPillar extends Ability
## Siku — Pillar (docs/NEW_HEROES.md §Siku).
##
## Ground only. A solid ice pillar builds under her — about 3 body-widths across
## and 3 body-heights tall — with an icy top, persisting for a few seconds
## before melting. Everyone standing in its footprint when it fires (Siku,
## allies and enemies alike; terrain does not take sides) is launched straight
## up, KEEPING their horizontal velocity: the JumpSpring recipe, including the
## request_state(&"Air") without which a grounded state erases the launch on the
## next frame (CLAUDE.md checklist).
##
## The headroom gate is the anti-stuck rule, and it lives in `_can_fire` rather
## than in a clamp: refused costs nothing (the base class spends nothing on a
## refusal), while a pillar that shortened itself to fit would be a different
## ability under every low ceiling. If there is not room for the whole column
## plus a standing body above the ground Siku is on, the cast simply does not
## happen — which is what makes "nobody ends up inside terrain" true by
## construction rather than by testing.

## 3 body-widths across, a shade over 2 body-heights tall (the body is 22x34) —
## brought down from 96 on the owner's pass, snapped to the tile grid.
@export var pillar_size: Vector2 = Vector2(64.0, 80.0)
@export var pillar_life: float = 5.0
## The launch: replaces velocity.y, keeps velocity.x. A medium distance — above
## a held jump's apex, well below a stage spring's 760-820, and comfortably
## past the pillar's own height so a launched body clears the cap.
@export var launch_velocity: float = -800.0
## Clearance the cast needs above the ground: the pillar, plus a standing body
## on top of it, plus a little slack.
@export var required_headroom: float = 122.0

## Half the body width, used to find the ground under her and to size the
## footprint scan. Not a feel number — it is the body.
const BODY_HALF_HEIGHT: float = 17.0
const GROUND_PROBE: float = 64.0
## How far the headroom probe is lifted off the floor it measures from.
const GROUND_INSET: float = 4.0

func _can_fire() -> bool:
	if not player.is_on_floor():
		return false
	var ground := _ground_point()
	if ground == Vector2.ZERO:
		return false
	return _has_headroom(ground)

func _execute(_aim: Vector2) -> void:
	var ground := _ground_point()
	# Launch first — but launching is not enough on its own: one frame at the
	# launch speed moves ~11px and the column is 80, so everyone launched is
	# also handed to the pillar as a collision exception until they have
	# physically cleared it (IcePillar.ignore_until_clear). Without that, the
	# solid appears around the bodies and depenetration shoves them out the
	# shortest way — for a body at the base, straight DOWN into the floor.
	var launched: Array = []
	for t in all_players():
		var body := t as Player
		if not _in_footprint(body, ground):
			continue
		body.velocity.y = launch_velocity          # velocity.x deliberately kept
		body.request_state(&"Air", {"anim": &"rise"})
		body.air_dash_locked = false
		launched.append(body)

	var pillar := IcePillar.new()
	pillar.pillar_size = pillar_size
	pillar.lifetime = pillar_life
	pillar.ignore_until_clear(launched)
	# The node's origin is the pillar's CAP, which is one pillar-height above
	# the ground it is built on.
	pillar.global_position = ground - Vector2(0.0, pillar_size.y)
	if player.hero != null:
		pillar.accent = player.hero.accent_color
	player.spawn_effect(pillar)

## The floor directly under Siku's feet. Vector2.ZERO if there is none within
## reach, which only happens if she left the ground between the gate and here.
func _ground_point() -> Vector2:
	var feet := player.global_position + Vector2(0.0, BODY_HALF_HEIGHT)
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(feet, feet + Vector2(0.0, GROUND_PROBE))
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector2.ZERO

## Is the column plus a standing body clear of terrain above this ground point?
##
## The probe is inset on three sides. Narrower than the pillar so a column built
## flush against a wall is not refused over a pixel of contact, and lifted clear
## of the floor because a box whose bottom edge sits exactly ON the ground
## reports that ground as an overlap — which would refuse the ability
## everywhere, standing on anything.
func _has_headroom(ground: Vector2) -> bool:
	var box := RectangleShape2D.new()
	box.size = Vector2(pillar_size.x - 4.0, required_headroom - GROUND_INSET)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	var centre := ground.y - GROUND_INSET - (required_headroom - GROUND_INSET) * 0.5
	query.transform = Transform2D(0.0, Vector2(ground.x, centre))
	query.collision_mask = 1
	return player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

## Standing in the column's footprint at cast time. Horizontal overlap with the
## pillar's width, and within a body's height of the same ground.
func _in_footprint(body: Player, ground: Vector2) -> bool:
	if absf(body.global_position.x - ground.x) > pillar_size.x * 0.5:
		return false
	var feet := body.global_position.y + BODY_HALF_HEIGHT
	return absf(feet - ground.y) <= BODY_HALF_HEIGHT * 2.0
