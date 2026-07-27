class_name SaiGrapple extends Ability
## Sai — throw a hook along the aim; if it bites terrain, swing (DESIGN 5.2).
## The pendulum itself lives in the Swing state; this just finds the anchor.
## A miss still costs the cooldown — hook shots are aimed, not free.
##
## Recasting while the rope is live reels him in instead of throwing again. That
## is one activation with two halves, so the recast rides through the cooldown
## the throw started and does not restart it: the swing and the pull-in are the
## same play, and charging twice would mean the only efficient use of the
## ability is the one that never uses half of it.

@export var range: float = 460.0

var _rope: GrappleRope = null

func _execute(aim: Vector2) -> void:
	if _roped():
		player.request_state(&"Reel", {"anchor": _rope.anchor})
		return
	var dir := aim_or_facing(aim)
	# Bias upward: a hook thrown flat at the floor is useless, and neutral input
	# should still produce a usable swing point.
	if absf(dir.y) < 0.2:
		dir = (dir + Vector2.UP * 0.6).normalized()
	var reach: Vector2 = player.global_position + dir * range
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(player.global_position, reach)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)

	# A miss throws the hook anyway. The cooldown is spent either way, and a
	# thrown hook that never appears reads as the ability failing to fire at all.
	_rope = GrappleRope.new()
	_rope.owner_player = player
	_rope.bites = not hit.is_empty()
	_rope.anchor = hit.position if _rope.bites else reach
	if player.hero != null:
		_rope.accent = player.hero.accent_color
	player.spawn_effect(_rope)

## Whether a hook of his is currently holding him. The rope frees itself the
## moment he leaves the states it holds through, so its being alive and attached
## is the same question as "is the recast available".
func _roped() -> bool:
	return _rope != null and is_instance_valid(_rope) and _rope.is_attached()

## The recast rides through the throw's cooldown.
func _on_cooldown() -> bool:
	if _roped():
		return false
	return super()

## ...and does not start a new one. Checked after _execute, by which point a
## recast has handed him to Reel — still a state the rope holds through.
func _cooldown_after_fire() -> bool:
	return not _roped()
