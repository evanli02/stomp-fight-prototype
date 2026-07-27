class_name StageGrid extends Node2D
## Design overlay for building stages. F3 toggles it in any stage.
##
## Stages are lists of Rect2 in code (IMPLEMENTATION.md 3a), which is fine to
## write and awful to iterate on: there is no way to look at the running game and
## know that the ledge you want goes at x=496, or that the gap you just made is
## 190px and therefore uncrossable. This draws the two things that answer both —
## the tile grid with coordinates on it, and the reach envelope around a body.
##
## The envelope is the useful half. Every number in it comes from
## tools/measure_reach.gd, so a movement tune moves the boxes too and the overlay
## cannot quietly start lying about what is reachable.

## Measured with tools/measure_reach.tscn. Re-run it after any movement tune and
## update these together.
const JUMP_APEX: float = 92.0          ## held jump, from flat ground
const JUMP_DASH_APEX: float = 103.0    ## jump then up-dash: the hard ceiling
const GAP_CAPPED: float = 133.0        ## held jump at a capped run
const GAP_JUMP_DASH: float = 275.0     ## capped jump + air dash, the widest sane gap

const MINOR: Color = Color(1, 1, 1, 0.05)
const MAJOR: Color = Color(0.49, 0.98, 1.0, 0.16)
const LABEL: Color = Color(0.75, 0.85, 1.0, 0.55)
const SPAWN: Color = Color(0.24, 0.86, 0.52, 0.9)
const REACH_UP: Color = Color(0.45, 0.85, 1.0, 0.5)
const REACH_OUT: Color = Color(1.0, 0.82, 0.25, 0.5)

@onready var _stage: MatchStage = get_parent() as MatchStage

var _on: bool = false

func _ready() -> void:
	z_index = 20
	visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	# A bare key, not a namespaced action: this is a tool for whoever is sitting
	# at the keyboard, not something a seat owns.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		_on = not _on
		visible = _on
		queue_redraw()

func _process(_delta: float) -> void:
	if _on:
		queue_redraw()

func _draw() -> void:
	if _stage == null:
		return
	var size := Vector2(_stage.arena_size()) * float(Arena.TILE)
	_draw_grid(size)
	_draw_spawns()
	_draw_reach()

## 16px minor, 64px major, coordinates every 128px. The labels are the point:
## they turn "somewhere left of the slab" into a number you can type into
## arena_blocks().
func _draw_grid(size: Vector2) -> void:
	var t := float(Arena.TILE)
	var font := ThemeDB.fallback_font
	var x := 0.0
	while x <= size.x:
		var major: bool = fmod(x, t * 4.0) < 0.5
		draw_line(Vector2(x, 0), Vector2(x, size.y), MAJOR if major else MINOR, 1.0)
		if fmod(x, t * 8.0) < 0.5 and x > 0.0:
			draw_string(font, Vector2(x + 2, 12), "%d" % int(x),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LABEL)
		x += t
	var y := 0.0
	while y <= size.y:
		var major: bool = fmod(y, t * 4.0) < 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), MAJOR if major else MINOR, 1.0)
		if fmod(y, t * 8.0) < 0.5 and y > 0.0:
			draw_string(font, Vector2(2, y - 2), "%d" % int(y),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LABEL)
		y += t

func _draw_spawns() -> void:
	var font := ThemeDB.fallback_font
	for seat in GameManager.seat_count():
		var at := _stage.spawn_for(seat)
		draw_line(at + Vector2(-10, 0), at + Vector2(10, 0), SPAWN, 1.5)
		draw_line(at + Vector2(0, -10), at + Vector2(0, 10), SPAWN, 1.5)
		draw_rect(Rect2(at - Vector2(11, 17), Vector2(22, 34)), SPAWN, false, 1.0)
		draw_string(font, at + Vector2(14, -14), "P%d spawn %d,%d" % [
			seat + 1, int(at.x), int(at.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SPAWN)

## What the first body can reach from where it is standing. Everything a stage
## needs to be legal is a comparison against these two boxes: a ledge higher than
## the blue line is unreachable, a gap wider than the outer gold line is a wall.
func _draw_reach() -> void:
	if _stage.players.is_empty():
		return
	var p: Player = _stage.players[0]
	if p == null or not is_instance_valid(p):
		return
	var at := p.global_position
	var font := ThemeDB.fallback_font

	for pair: Array in [[JUMP_APEX, "jump", REACH_UP], [JUMP_DASH_APEX, "jump+updash", REACH_UP]]:
		var h: float = pair[0]
		draw_line(at + Vector2(-140, -h), at + Vector2(140, -h), pair[2], 1.0)
		draw_string(font, at + Vector2(142, -h + 3), "%s %dpx" % [pair[1], int(h)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, pair[2])

	for pair2: Array in [[GAP_CAPPED, "jump gap"], [GAP_JUMP_DASH, "jump+dash gap"]]:
		var w: float = pair2[0]
		for s: float in [-1.0, 1.0]:
			draw_line(at + Vector2(s * w, -60), at + Vector2(s * w, 20), REACH_OUT, 1.0)
		draw_string(font, at + Vector2(w + 4, 16), "%s %dpx" % [pair2[1], int(w)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, REACH_OUT)

	draw_string(font, at + Vector2(-30, -108), "%d, %d" % [int(at.x), int(at.y)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
