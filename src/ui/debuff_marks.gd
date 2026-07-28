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
## How many dart stacks the pip badge draws slots for. Matches Vesper's
## stacks_to_sleep — the badge is a countdown, so it has to show the whole count.
const SLEEP_PIPS: int = 3

## tag -> [colour, shape]. Shape carries the meaning for colourblind players;
## colour is the fast read for everyone else.
const MARKS: Dictionary = {
	&"slash": [Color(1, 0.43, 0.78), "slash"],
	&"emp": [Color(1, 0.55, 0.18), "bolt"],
	&"fracture": [Color(0.71, 0.40, 0.11), "chain"],
	&"teleport": [Color(0.11, 0.43, 0.82), "ring"],
	&"slow": [Color(0.75, 0.75, 0.85), "ring"],
	&"impair": [Color(0.75, 0.75, 0.85), "chain"],
	&"ignite": [Color(0.75, 0.37, 1.0), "ring"],
	# Vesper's stacks draw as PIPS — a count, not a state. How many is the whole
	# information: two pips means the next dart puts you under.
	&"dart": [Color(1, 0.18, 0.77), "pips"],
	&"sleep": [Color(1, 0.18, 0.77), "zzz"],
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
		"pips":       # one filled dot per sleep stack, empty for the rest
			var have: int = _player.sleep_stacks if _player != null else 0
			for i in SLEEP_PIPS:
				var spot := at + Vector2((float(i) - 1.0) * 4.0, 0.0)
				if i < have:
					draw_circle(spot, 1.8, col)
				else:
					draw_arc(spot, 1.8, 0.0, TAU, 8, Color(col.r, col.g, col.b, 0.45), 1.0)
		"zzz":        # asleep: the universal read, drawn as stacked strokes
			for i in 3:
				var y := -SIZE + float(i) * 3.5
				var w := (SIZE - float(i)) * 0.8
				draw_line(at + Vector2(-w, y), at + Vector2(w, y), col, 1.5)
				draw_line(at + Vector2(w, y), at + Vector2(-w, y + 3.0), col, 1.0)
		_:            # ring: a plain slow
			draw_arc(at, SIZE, 0.0, TAU, 16, col, 2.0)
