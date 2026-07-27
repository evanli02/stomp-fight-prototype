class_name DebuffMarks extends Node2D
## Distinct badges over a debuffed player, one per source. A player who cannot
## tell WHY they are slowed cannot decide what to do about it: an EMP means wait,
## a slash means you still have a dash, a fracture means you are stuck on the
## floor. Same information, different answers — so they get different marks.
##
## Sibling of the sprite so it does not flip with facing.

const HEIGHT_ABOVE_HEAD: float = -36.0
const SIZE: float = 5.0
const GAP: float = 12.0

## tag -> [colour, shape]. Shape carries the meaning for colourblind players;
## colour is the fast read for everyone else.
const MARKS: Dictionary = {
	&"slash": [Color(1, 0.43, 0.78), "slash"],
	&"emp": [Color(1, 0.55, 0.18), "bolt"],
	&"fracture": [Color(0.71, 0.40, 0.11), "chain"],
	&"teleport": [Color(0.18, 0.89, 0.90), "ring"],
	&"slow": [Color(0.75, 0.75, 0.85), "ring"],
	&"impair": [Color(0.75, 0.75, 0.85), "chain"],
}

@onready var _player: Player = get_parent() as Player

func _ready() -> void:
	position.y = HEIGHT_ABOVE_HEAD
	z_index = 11

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _player == null or _player.debuff_tags.is_empty():
		return
	var tags: Array = _player.debuff_tags.keys()
	tags.sort()   # stable order, so badges do not swap places frame to frame
	var row_w := tags.size() * GAP
	var x := -row_w * 0.5 + GAP * 0.5
	for i in tags.size():
		var tag: StringName = tags[i]
		var entry: Array = MARKS.get(tag, [Color.WHITE, "ring"])
		_draw_mark(Vector2(x + i * GAP, 0.0), entry[0], entry[1])

func _draw_mark(at: Vector2, col: Color, shape: String) -> void:
	# Dark plate behind every badge: these sit over a busy stage.
	draw_circle(at, SIZE + 1.5, Color(0.05, 0.03, 0.09, 0.85))
	match shape:
		"slash":      # a cut: two quick strokes
			draw_line(at + Vector2(-SIZE, SIZE), at + Vector2(SIZE, -SIZE), col, 2.0)
			draw_line(at + Vector2(-SIZE * 0.4, SIZE), at + Vector2(SIZE, -SIZE * 0.2), col, 1.0)
		"bolt":       # a lightning kink: tech is off
			draw_line(at + Vector2(1.5, -SIZE), at + Vector2(-1.5, 0), col, 2.0)
			draw_line(at + Vector2(-1.5, 0), at + Vector2(1.5, 0), col, 2.0)
			draw_line(at + Vector2(1.5, 0), at + Vector2(-1.5, SIZE), col, 2.0)
		"chain":      # bars: pinned to the ground
			draw_line(at + Vector2(-SIZE, -2), at + Vector2(SIZE, -2), col, 2.0)
			draw_line(at + Vector2(-SIZE, 2), at + Vector2(SIZE, 2), col, 2.0)
		_:            # ring: a plain slow
			draw_arc(at, SIZE, 0.0, TAU, 16, col, 2.0)
