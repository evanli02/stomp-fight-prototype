extends MatchStage
## Sunken Court: two solid mesas with a sprung trench between them, one contested
## platform over the middle, and a pole above each mesa.
##
## Built from a sketch, with every distance checked against the reach envelope in
## docs/MAPS.md. The design question it asks is the opposite of Rooftop Rumble's:
## Rooftop is a runway and rewards carrying speed sideways, so this one is a
## vertical arena that rewards choosing a height and holding it. The trench in
## the middle is genuinely hard to climb out of on your own, which makes the
## springs the route and makes being knocked into it cost something.
##
## Nothing here can take a life — the trench is a low place, not a pit
## (DESIGN 6.1, CLAUDE.md 2).

## Medium (DESIGN 6.1: ~56x32).
const ARENA: Vector2i = Vector2i(56, 32)
const FLOOR_TOP: float = 496.0

## Mesa tops, and the spawns that sit on them. Bodies stand 24px above a surface.
const MESA_TOP: float = 368.0
const SPAWNS: Array[Vector2] = [Vector2(120, 344), Vector2(776, 344)]

## The trench between the mesas: 320px wide, 128px deep.
##
## Deeper than a held jump (92px) on purpose. You cannot simply hop out, and the
## facing mesa walls are too far apart to wall-jump across without losing height,
## so the springs are the way out.
const TRENCH_LEFT: float = 288.0
const TRENCH_RIGHT: float = 608.0
## Five springs, wall to wall, no standing room. A 22px body always touches one,
## so the trench cannot be occupied — you enter it, you bounce, you steer your way
## out. Springs keep horizontal speed, so each bounce banks whatever air control
## added to the last one and the exit builds itself over two or three arcs.
const SPRING_COUNT: int = 5

## The contested platform: exactly as long as the trench and directly over it, so
## the pit reads as roofed and the high ground is the pit's ceiling.
##
## At 96px above a mesa top it sits just PAST the 92px held jump and inside the
## 103px jump-plus-up-dash ceiling, so taking the high ground costs a dash
## charge. That is a real change from the first pass, where it was an ordinary
## jump — one tile is the smallest raise the grid allows and this is which side
## of the threshold it lands on.
const PLATFORM_TOP: float = 272.0

## Springs clear the trench lip but stop short of the platform roofing it: 820
## lifts a body about 177px, leaving its head clear of the underside. The floor
## throws you out of the hole; it never hands you the ceiling.
const SPRING_LAUNCH: Vector2 = Vector2(0, -820)

const BACKDROP: Array[Color] = [
	Color(0.09, 0.05, 0.11), Color(0.16, 0.08, 0.13),
	Color(0.26, 0.12, 0.14), Color(0.42, 0.20, 0.16),
]
const GROUND_FILL: Color = Color(0.07, 0.04, 0.07)
const CAP: Color = Color(0.95, 0.55, 0.28)
const HORIZON_Y: float = 368.0

var _ground_tex: Texture2D = load("res://assets/stages/tile_court.png")

func stage_id() -> StringName: return &"sunken_court"
func arena_size() -> Vector2i: return ARENA
func spawns() -> Array[Vector2]: return SPAWNS
func sky_bands() -> Array[Color]: return BACKDROP
func horizon() -> float: return HORIZON_Y
func ground_fill() -> Color: return GROUND_FILL
func cap_color() -> Color: return CAP
func ground_texture() -> Texture2D: return _ground_tex

## Two solid mesas either side of a trench, plus the platform over it.
##
## The mesas are solid rather than slabs on stilts (which is what Rooftop's
## rooftops are): the sketch has them filled, and it changes the stage's
## character — there is no space underneath to run through, so the trench is the
## only low route and crossing at the bottom means committing to it.
##
## Each mesa top is 320px of flat ground, which is enough runway to build a
## capped run and b-hop along, but not the full-width runway Rooftop has. That is
## the trade this layout makes.
func arena_blocks() -> Array[Rect2]:
	var blocks := Arena.sealed_box(ARENA)
	blocks.append_array([
		# Left mesa: from the wall to the trench, floor to MESA_TOP.
		Rect2(16.0, MESA_TOP, TRENCH_LEFT - 16.0, FLOOR_TOP - MESA_TOP),
		# Right mesa, mirrored.
		Rect2(TRENCH_RIGHT, MESA_TOP, 880.0 - TRENCH_RIGHT, FLOOR_TOP - MESA_TOP),
		# Same length as the gap it covers, by construction rather than by a
		# number that has to be kept in step.
		Rect2(TRENCH_LEFT, PLATFORM_TOP, TRENCH_RIGHT - TRENCH_LEFT, 16.0),
	])
	return blocks

func build_terrain() -> void:
	_build_springs()
	_build_poles()

## Springs tiled edge to edge across the whole trench floor. Butted together with
## no seam on purpose: a 22px body standing in any gap would have somewhere to
## rest, and the trench is meant to be a place you pass through, not hold.
func _build_springs() -> void:
	var width := (TRENCH_RIGHT - TRENCH_LEFT) / float(SPRING_COUNT)
	for i in SPRING_COUNT:
		var spring := JumpSpring.new()
		spring.size = Vector2(width, 16.0)
		# Sitting ON the trench floor: the trigger's top edge meets the surface.
		spring.position = Vector2(
			TRENCH_LEFT + width * (float(i) + 0.5), FLOOR_TOP - 8.0)
		spring.launch_velocity = SPRING_LAUNCH
		add_child(spring)

## A pole directly over each spawn, as far apart as the mesas allow. Their lower
## ends hang at y=280, which a held jump from the mesa (apex 252) passes on the
## way up — so they are grabbed in flight, and grabbing one refills the dash and
## kills momentum. Parking the reset over the spawn means the ground a player
## already owns is also where they can recover, and it puts the two of them a
## full stage apart.
func _build_poles() -> void:
	for x: float in [SPAWNS[0].x, SPAWNS[1].x]:
		var pole := Pole.new()
		pole.size = Vector2(8, 160)
		pole.position = Vector2(x, 200)
		add_child(pole)

## Trench shadow and a lip along each mesa edge, so the drop reads as a drop
## before someone is standing in it.
func _draw() -> void:
	super()
	var depth := FLOOR_TOP - MESA_TOP
	draw_rect(Rect2(TRENCH_LEFT, MESA_TOP, TRENCH_RIGHT - TRENCH_LEFT, depth),
		Color(0.0, 0.0, 0.0, 0.22))
	for x: float in [TRENCH_LEFT, TRENCH_RIGHT - 3.0]:
		draw_rect(Rect2(x, MESA_TOP, 3.0, depth), Color(CAP.r, CAP.g, CAP.b, 0.35))
	draw_rect(Rect2(TRENCH_LEFT, MESA_TOP - 2.0, TRENCH_RIGHT - TRENCH_LEFT, 2.0),
		Color(CAP.r, CAP.g, CAP.b, 0.5))
