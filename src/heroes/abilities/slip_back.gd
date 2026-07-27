class_name SlipBack extends Ability
## Slip — drop an anchor, then rewind to it (DESIGN 5.2). The rewind replays her
## actual path at very high speed (the Recall state), so it reads as a rewind
## rather than a blink.
##
## Multi-stage cooldown: placing starts the cooldown, but the rewind is allowed
## THROUGH that cooldown while the anchor lives — the pair is one play, and an
## anchor expiring unanswered is its own small punishment.

@export var anchor_lifetime: float = 6.0

var _anchor_active: bool = false
var _anchor_pos: Vector2 = Vector2.ZERO
var _anchor_age: float = 0.0
var _trail: Array = []
var _marker: SlipAnchor = null

func _physics_process(delta: float) -> void:
	super(delta)
	if not _anchor_active:
		return
	_anchor_age += delta
	if _anchor_age >= anchor_lifetime:
		_anchor_active = false
		_trail.clear()
		_clear_marker()
		return
	_trail.append(player.global_position)

func _on_cooldown() -> bool:
	if _anchor_active:
		return false   # the rewind rides through the placement's cooldown
	return super()

func _cooldown_after_fire() -> bool:
	# Runs after _execute: a placement has just SET _anchor_active, a recall has
	# just cleared it. Only the placement starts the clock.
	return _anchor_active

func _execute(_aim: Vector2) -> void:
	if _anchor_active:
		_anchor_active = false
		var path := _trail.duplicate()
		_trail.clear()
		_clear_marker()
		path.push_front(_anchor_pos)
		player.request_state(&"Recall", {"path": path})
		return
	_anchor_active = true
	_anchor_age = 0.0
	_anchor_pos = player.global_position
	_trail = [player.global_position]
	_clear_marker()
	_marker = SlipAnchor.new()
	_marker.global_position = _anchor_pos
	_marker.duration = anchor_lifetime
	if player.hero != null:
		_marker.accent = player.hero.accent_color
	player.spawn_effect(_marker)

func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
