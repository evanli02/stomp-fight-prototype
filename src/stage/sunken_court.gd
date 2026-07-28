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

## The trench between the mesas: 224px wide, 128px deep.
##
## Deeper than a held jump (92px) on purpose. You cannot simply hop out, and the
## facing mesa walls are too far apart to wall-jump across without losing height,
## so the springs are the way out. That is what makes the trench a real place
## rather than a decorative dip — and why there are three springs, so it is never
## a trap.
const TRENCH_LEFT: float = 336.0
const TRENCH_RIGHT: float = 560.0
## Plain floor left un-sprung against each trench wall, wider than the 22px body
## so there is somewhere down there to actually stand.
const LEDGE: float = 32.0

## The contested platform, 80px above a mesa top: inside a held jump (92px) from
## either side, so it is reachable without spending a dash but not by accident.
const PLATFORM: Rect2 = Rect2(392.0, 288.0, 112.0, 16.0)

## Springs clear the trench and land you on a mesa, but deliberately stop short
## of the platform overhead — 820 lifts a body about 177px, and the platform's
## underside is 26px above that apex. Getting to the high ground is a jump you
## choose from the top, not something the floor does for you.
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
		PLATFORM,
	])
	return blocks

func build_terrain() -> void:
	_build_springs()
	_build_poles()

## Three springs across the trench floor, inset from its walls.
##
## The inset is the whole difference between a trench and a bounce pad. Bodies
## are 22px wide, so springs running wall to wall mean you can never stand down
## there at all — you touch the floor and you are gone. LEDGE px of plain floor
## at each end makes the trench somewhere you can choose to be: drop in, fight,
## and leave on a spring when you want to.
##
## They keep whatever horizontal speed you bring in (that is what makes them
## chainable), so which one you hit decides where you come out.
func _build_springs() -> void:
	var span := (TRENCH_RIGHT - LEDGE) - (TRENCH_LEFT + LEDGE)
	var width := span / 3.0
	for i in 3:
		var spring := JumpSpring.new()
		spring.size = Vector2(width - 4.0, 16.0)
		# Sitting ON the trench floor: the trigger's top edge meets the surface.
		spring.position = Vector2(
			TRENCH_LEFT + LEDGE + width * (float(i) + 0.5), FLOOR_TOP - 8.0)
		spring.launch_velocity = SPRING_LAUNCH
		add_child(spring)

## A pole above each mesa. Their lower ends hang at y=280, which a held jump from
## the mesa (apex 252) passes on the way up — so they are grabbed in flight, and
## grabbing one refills the dash and kills momentum. That is the reset button,
## parked over the ground each side already owns.
func _build_poles() -> void:
	for x: float in [224.0, 672.0]:
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
