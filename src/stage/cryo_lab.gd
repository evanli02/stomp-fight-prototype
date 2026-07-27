extends MatchStage
## Cryo Lab (DESIGN 6.3): a sealed cryogenics floor. Ice underfoot, a laser grid
## on a timer, and one portal pair running the length of the room.
##
## The design brief opposite Rooftop Rumble: Rooftop is open and about carrying
## speed, so this one is about *placing* it. The floor does not let you stop
## where you meant to, the lasers decide when a lane is open, and the portals
## mean the far side of the room is never as far away as it looks.

## Medium (DESIGN 6.1: ~56x32). Smaller than Rooftop on purpose — the ice
## already stretches every commitment, and a Large stage of it would be all
## travel and no contact.
const ARENA: Vector2i = Vector2i(56, 32)
## Opposite ends of the lab floor. Body centres sit 24px above a surface.
const SPAWNS: Array[Vector2] = [Vector2(120, 472), Vector2(776, 472)]
const FLOOR_TOP: float = 496.0
## No sky: this is indoors. The "gradient" is the far wall of the lab, going
## from ceiling glow down to the frost line, and the horizon is the frost line.
const FROST_LINE: float = 400.0
const BACKDROP: Array[Color] = [
	Color(0.05, 0.11, 0.17), Color(0.07, 0.16, 0.23),
	Color(0.09, 0.22, 0.29), Color(0.12, 0.30, 0.35),
]
const GROUND_FILL: Color = Color(0.04, 0.08, 0.13)
const CAP: Color = Color(0.49, 0.98, 1.0)

## How long one full dark->live->dark pass of the grid takes, and how much of it
## a line is live for. One clock for the whole grid so the phases below read as
## a pattern rather than as noise.
const GRID_CYCLE: float = 3.0
const GRID_ON: float = 0.45

var _ground_tex: Texture2D = load("res://assets/stages/tile_lab.png")

func stage_id() -> StringName: return &"cryo_lab"
func arena_size() -> Vector2i: return ARENA
func spawns() -> Array[Vector2]: return SPAWNS
func sky_bands() -> Array[Color]: return BACKDROP
func horizon() -> float: return FROST_LINE
func ground_fill() -> Color: return GROUND_FILL
func cap_color() -> Color: return CAP
func ground_texture() -> Texture2D: return _ground_tex

## Four tiers around a central containment cell, symmetric about x=448.
##
## The two columns hanging off the cell make a 128px shaft directly under the
## most valuable platform in the room: the fast way up is a wall-jump chain, and
## it puts you somewhere contested when you arrive. Everything else is reachable
## on foot, because ice plus a forced jump is a coin flip rather than a choice.
##
## Sealed box, no pits (DESIGN 6.1).
func arena_blocks() -> Array[Rect2]:
	var t := float(Arena.TILE)
	var blocks := Arena.sealed_box(ARENA)
	blocks.append_array([
		Rect2(160.0, 384.0, 160.0, t),   # left mid bench
		Rect2(576.0, 384.0, 160.0, t),   # right mid bench
		Rect2(368.0, 304.0, 160.0, t),   # containment cell, the contested slab
		Rect2(368.0, 320.0, t, 96.0),    # cell column, inner face at x=384
		Rect2(512.0, 320.0, t, 96.0),    # cell column, inner face at x=512
		Rect2(96.0, 224.0, 144.0, t),    # left catwalk
		Rect2(656.0, 224.0, 144.0, t),   # right catwalk
		Rect2(400.0, 144.0, 96.0, t),    # crown, above the cell
	])
	return blocks

## Exactly what DESIGN 6.3 calls for: ice floors, a timed stun-line grid, and a
## portal pair.
func build_terrain() -> void:
	_build_ice()
	_build_grid()
	_build_portals()

## Ice on the outer thirds of the floor and on both mid benches. The centre of
## the floor is deliberately grippy: with the whole room slick there is nowhere
## to plant a stomp from, and the stage stops being about aim.
func _build_ice() -> void:
	for spot: Vector2 in [Vector2(200, 472), Vector2(696, 472)]:
		_add_ice(spot, Vector2(240, 40))
	for spot: Vector2 in [Vector2(240, 360), Vector2(656, 360)]:
		_add_ice(spot, Vector2(160, 40))

func _add_ice(at: Vector2, extent: Vector2) -> void:
	var sheet := Ice.new()
	sheet.size = extent
	sheet.position = at
	add_child(sheet)

## The grid: two lanes across the floor approach and two across the cell, run on
## opposite halves of the same cycle. Crossing costs a stun if you mistime it,
## so the room has a rhythm without ever closing a route permanently.
func _build_grid() -> void:
	# Floor approaches — the price of running the outer lanes flat out.
	for x: float in [320.0, 576.0]:
		_add_line(Vector2(x, 448.0), Vector2(8, 96), 0.0)
	# Under the cell, across the wall-jump shaft.
	_add_line(Vector2(448.0, 400.0), Vector2(128, 8), 0.5)
	# Across the top of the cell itself: holding the best platform should mean
	# watching a clock.
	_add_line(Vector2(448.0, 296.0), Vector2(160, 8), 0.25)

func _add_line(at: Vector2, extent: Vector2, phase: float) -> void:
	var line := StunLine.new()
	line.size = extent
	line.position = at
	line.cycle_time = GRID_CYCLE
	line.on_ratio = GRID_ON
	line.phase_offset = phase
	add_child(line)

## One pair, both ends on the floor at opposite walls, both facing the same way
## so velocity comes out of the exit exactly as it went into the entrance. A
## player who commits to a full-speed run down one wall reappears behind the
## other spawn still at that speed — the only way to cross the room faster than
## the ice lets you.
func _build_portals() -> void:
	var left := Portal.new()
	left.size = Vector2(28, 56)
	left.position = Vector2(64, 464)
	left.facing = Vector2.RIGHT
	var right := Portal.new()
	right.size = Vector2(28, 56)
	right.position = Vector2(832, 464)
	right.facing = Vector2.RIGHT
	add_child(left)
	add_child(right)
	left.linked_portal = left.get_path_to(right)
	right.linked_portal = right.get_path_to(left)

## Frost creeping up the walls, plus the cell's containment glow. Drawn under
## the blocks so nothing here can be mistaken for a surface.
func _draw() -> void:
	super()
	var w := float(ARENA.x * Arena.TILE)
	for i in 3:
		var y := FLOOR_TOP - 8.0 - i * 5.0
		draw_rect(Rect2(0.0, y, w, 2.0), Color(0.49, 0.98, 1.0, 0.10 - i * 0.03))
	draw_rect(Rect2(368.0, 288.0, 160.0, 16.0), Color(0.49, 0.98, 1.0, 0.07))
