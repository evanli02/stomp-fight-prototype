class_name AimLine extends Node2D
## The guide line showing where a player is pointing (DESIGN 7: the aim vector is
## always live). Aimed abilities — Sai's hook, Deadeye's bolt, Terra's fracture,
## Kid's cannon — were being thrown at a direction the player could only infer
## from a cursor somewhere else on screen, or from a right stick with no readout
## at all. This puts the answer where the character is.
##
## Deliberately short and deliberately blocked by terrain. An infinite ray would
## be a laser sight, which is a different game: knowing your exact line to the
## other side of the stage turns aimed abilities into hitscan. Six body-heights
## is about the useful range of the abilities it serves, and stopping at the
## first wall means the line also reads as "the hook bites here".
##
## Sibling of the sprite, not a child, so it does not flip with facing.

## Six times a hero's frame height (32x36 sprites, DESIGN 8).
const HERO_HEIGHT: float = 36.0
const LENGTH: float = HERO_HEIGHT * 6.0
const WIDTH: float = 1.5
## Dashes rather than a solid stroke: a solid line at this length reads as a
## wall or a rope, and this is neither.
const DASH: float = 7.0
const GAP: float = 5.0
## Held back so the line starts outside the body instead of under the sprite.
const MUZZLE: float = 12.0
const COL_OUTLINE: Color = Color(0.05, 0.03, 0.09, 0.5)

@onready var _player: Player = get_parent() as Player

## Resolved on the physics tick (a space query cannot safely run mid-render) and
## drawn from the cached result.
var _length: float = LENGTH
var _direction: Vector2 = Vector2.RIGHT
var _blocked: bool = false

func _ready() -> void:
	z_index = 9   # under the status readout, over the stage

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_direction = _aim()
	_length = LENGTH
	_blocked = false
	var space := _player.get_world_2d().direct_space_state
	var from := _player.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + _direction * LENGTH)
	query.collision_mask = 1        # terrain only; bodies are layer 2
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_length = from.distance_to(hit.position)
		_blocked = true
	queue_redraw()

## Resolved length and whether terrain cut it short. Read by the match harness:
## the line makes a promise about where a cast goes, and the two ways it can lie
## are drawing through a wall and pointing somewhere a cast would not.
func debug_length() -> float: return _length
func debug_blocked() -> bool: return _blocked
func debug_direction() -> Vector2: return _direction

## Aim if the stick or cursor says anything, facing otherwise — the same
## fallback the abilities themselves use, so the line never promises a direction
## a cast would not take.
func _aim() -> Vector2:
	var aim: Vector2 = _player.input.aim
	if aim.length() > 0.1:
		return aim.normalized()
	return Vector2(float(_player.facing), 0.0)

func _draw() -> void:
	# Nothing to aim with while stunned or frozen, and a line drawn anyway would
	# say the opposite.
	if _player == null or not _player.can_act():
		return
	var accent: Color = _player.hero.accent_color if _player.hero != null else Color.WHITE
	var at := MUZZLE
	while at < _length:
		var to := minf(at + DASH, _length)
		# Fades out along its length: the near end is where the information is.
		var t := 1.0 - at / _length
		var alpha := 0.16 + 0.34 * t
		draw_line(_direction * at, _direction * to,
			Color(COL_OUTLINE.r, COL_OUTLINE.g, COL_OUTLINE.b, alpha * 0.8), WIDTH + 1.5)
		draw_line(_direction * at, _direction * to,
			Color(accent.r, accent.g, accent.b, alpha), WIDTH)
		at = to + GAP
	_draw_tip(accent)

## A bar across the end when terrain stopped it, an open chevron when it did not
## — the difference between "this is where it lands" and "this is only a
## direction" is worth one glance.
func _draw_tip(accent: Color) -> void:
	var end := _direction * _length
	var side := _direction.orthogonal()
	var col := Color(accent.r, accent.g, accent.b, 0.55)
	if _blocked:
		draw_line(end - side * 4.0, end + side * 4.0, COL_OUTLINE, 3.5)
		draw_line(end - side * 4.0, end + side * 4.0, col, 2.0)
		return
	for s: float in [-1.0, 1.0]:
		var wing := end - _direction * 4.0 + side * s * 3.0
		draw_line(end, wing, COL_OUTLINE, 3.0)
		draw_line(end, wing, col, 1.5)
