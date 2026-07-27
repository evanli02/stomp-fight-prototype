class_name SaiSlash extends Ability
## Sai's ultimate (DESIGN 5.2): cross a long straight line instantly, through
## bodies but never through terrain. Everyone he passes is slowed and has their
## jump, dash, and wall jump gutted for a window — hit by the slash, you still
## move, but you stop being a platform fighter for a few seconds.

@export var distance: float = 520.0
@export var corridor: float = 34.0
@export var slow_mult: float = 0.415
@export var impair_mult: float = 0.3
@export var debuff_time: float = 7.0

func _execute(aim: Vector2) -> void:
	var dir := aim_or_facing(aim)
	var from := player.global_position
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * distance)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	var to: Vector2 = (hit.position - dir * 14.0) if not hit.is_empty() else from + dir * distance

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
