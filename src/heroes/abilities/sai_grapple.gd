class_name SaiGrapple extends Ability
## Sai — throw a hook along the aim; if it bites terrain, swing (DESIGN 5.2).
## The pendulum itself lives in the Swing state; this just finds the anchor.
## A miss still costs the cooldown — hook shots are aimed, not free.

@export var range: float = 300.0

func _execute(aim: Vector2) -> void:
	var dir := aim_or_facing(aim)
	# Bias upward: a hook thrown flat at the floor is useless, and neutral input
	# should still produce a usable swing point.
	if absf(dir.y) < 0.2:
		dir = (dir + Vector2.UP * 0.6).normalized()
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		player.global_position, player.global_position + dir * range)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var anchor: Vector2 = hit.position
	var rope := GrappleRope.new()
	rope.owner_player = player
	rope.anchor = anchor
	if player.hero != null:
		rope.accent = player.hero.accent_color
	player.spawn_effect(rope)
	player.request_state(&"Swing", {"anchor": anchor})
