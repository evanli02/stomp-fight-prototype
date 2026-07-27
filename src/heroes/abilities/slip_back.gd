class_name SlipBack extends Ability
## Slip — drop an anchor, then rewind to it (DESIGN 5.2). The rewind is an
## instant teleport back to the anchor (the Recall state); the path she took to
## get away from it is not recorded and does not matter.
##
## Multi-stage cooldown: placing starts the cooldown, but the rewind is allowed
## THROUGH that cooldown while the anchor lives — the pair is one play, and an
## anchor expiring unanswered is its own small punishment.

@export var anchor_lifetime: float = 6.0

## How long the puff left behind at the departure point lingers. Cosmetic.
const DEPART_FLASH_TIME: float = 0.3

var _anchor_active: bool = false
var _anchor_pos: Vector2 = Vector2.ZERO
var _anchor_age: float = 0.0
var _marker: SlipAnchor = null

func _physics_process(delta: float) -> void:
	super(delta)
	if not _anchor_active:
		return
	_anchor_age += delta
	if _anchor_age >= anchor_lifetime:
		_anchor_active = false
		_clear_marker()

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
		_clear_marker()
		# A flash where she left, so the blink has two readable ends rather than
		# one: the departure is the only cue an opponent gets.
		var flash := SlipAnchor.new()
		flash.global_position = player.global_position
		flash.duration = DEPART_FLASH_TIME
		if player.hero != null:
			flash.accent = player.hero.accent_color
		player.spawn_effect(flash)
		player.request_state(&"Recall", {"to": _anchor_pos})
		return
	_anchor_active = true
	_anchor_age = 0.0
	_anchor_pos = player.global_position
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
