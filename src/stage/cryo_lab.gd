extends MatchStage
## Cryo Lab: a sealed cryogenics floor where every surface is ice and the way up
## is a teleporter, not a jump.
##
## Rebuilt from a layout sketch. The stack of platforms climbs the left and right
## halves in reachable 64px steps, but the 192px between the lower chamber and
## the centre slab is deliberately past anything a jump can do — that gap is
## crossed on a pole or through a portal, and choosing which is the stage.
##
## Three colour-coded portal pairs:
##   red     bottom-right  <-> top-left
##   purple  bottom-left   <-> top-right
##   green   mid-left      <-> mid-right
## The two diagonal pairs are escalators: run into a bottom corner and come out
## high on the opposite side, still carrying whatever speed you arrived with.
## Green is the flat shortcut, and the only one you have to be airborne to take.
##
## Everything underfoot is ice, so none of that traversal ends where you meant it
## to unless you planned the stop. Nothing here can take a life (CLAUDE.md 1).

## Medium (DESIGN 6.1: ~56x32).
const ARENA: Vector2i = Vector2i(56, 32)
const FLOOR_TOP: float = 496.0

## Platform tops, high to low. Each neighbouring pair is 64px apart, inside the
## 92px held jump, so the left and right halves are climbable on foot.
const CROWN_TOP: float = 96.0     ## small platform under the ceiling
const LEDGE_TOP: float = 160.0    ## upper side ledges
const SLAB_TOP: float = 224.0     ## the wide centre slab
const SHELF_TOP: float = 416.0    ## low side shelves, 80px above the floor

## The centre slab, and the flanking ledges that meet its edges.
const SLAB_LEFT: float = 288.0
const SLAB_RIGHT: float = 608.0

## Spawns sit on the low side shelves: opposite ends, each with a portal under it.
const SPAWNS: Array[Vector2] = [Vector2(96, 392), Vector2(800, 392)]

const PORTAL_SIZE: Vector2 = Vector2(40, 56)
const COL_RED: Color = Color(0.93, 0.42, 0.42)
const COL_PURPLE: Color = Color(0.60, 0.48, 0.86)
const COL_GREEN: Color = Color(0.55, 0.83, 0.51)

## No sky: this is indoors. The gradient is the far wall of the lab, from ceiling
## glow down to the frost line.
const FROST_LINE: float = 416.0
const BACKDROP: Array[Color] = [
	Color(0.05, 0.11, 0.17), Color(0.07, 0.16, 0.23),
	Color(0.09, 0.22, 0.29), Color(0.12, 0.30, 0.35),
]
const GROUND_FILL: Color = Color(0.04, 0.08, 0.13)
const CAP: Color = Color(0.49, 0.98, 1.0)

var _ground_tex: Texture2D = load("res://assets/stages/tile_lab.png")

func stage_id() -> StringName: return &"cryo_lab"
func arena_size() -> Vector2i: return ARENA
func spawns() -> Array[Vector2]: return SPAWNS
func sky_bands() -> Array[Color]: return BACKDROP
func horizon() -> float: return FROST_LINE
func ground_fill() -> Color: return GROUND_FILL
func cap_color() -> Color: return CAP
func ground_texture() -> Texture2D: return _ground_tex

## Every walkable surface in the stage, listed once so the ice below can be laid
## over exactly the same set. A platform that got added here and forgotten there
## would be the one patch of grip in an ice level, which is worse than either.
func platforms() -> Array[Rect2]:
	return [
		Rect2(352.0, CROWN_TOP, 192.0, 16.0),                     # crown
		Rect2(128.0, LEDGE_TOP, 160.0, 16.0),                     # upper left
		Rect2(608.0, LEDGE_TOP, 160.0, 16.0),                     # upper right
		Rect2(SLAB_LEFT, SLAB_TOP, SLAB_RIGHT - SLAB_LEFT, 16.0), # centre slab
		Rect2(16.0, SHELF_TOP, 160.0, 16.0),                      # low left shelf
		Rect2(720.0, SHELF_TOP, 160.0, 16.0),                     # low right shelf
	]

func arena_blocks() -> Array[Rect2]:
	var blocks := Arena.sealed_box(ARENA)
	blocks.append_array(platforms())
	return blocks

func build_terrain() -> void:
	_build_ice()
	_build_poles()
	_build_portals()

## Ice over every platform top and the whole floor. The element acts on a body
## that is standing in it, so each sheet is centred a body-height above the
## surface rather than sitting on it.
func _build_ice() -> void:
	for block: Rect2 in platforms():
		_ice_over(block.position.x, block.position.x + block.size.x, block.position.y)
	_ice_over(16.0, 880.0, FLOOR_TOP)

func _ice_over(left: float, right: float, surface_y: float) -> void:
	var sheet := Ice.new()
	sheet.size = Vector2(right - left, 40.0)
	sheet.position = Vector2((left + right) * 0.5, surface_y - 24.0)
	add_child(sheet)

## Three poles hanging in the lower chamber, which is the only place in the
## stage where 192px of empty air needs crossing on foot.
##
## The outer two sit just OUTSIDE the slab's edges rather than under it, which is
## a deliberate departure from the sketch: a pole directly beneath the slab tops
## out against its underside, so climbing one would end with a jump into the
## ceiling. Clear of the edge, the climb ends with a jump onto the slab, and the
## lower chamber has a way up that is not a portal.
##
## The middle one stays under the slab and runs longer, exactly as drawn. It
## cannot reach the top, and that is its job: it is the reposition and dash
## refill in the middle of the room, not a route.
func _build_poles() -> void:
	for x: float in [264.0, 632.0]:
		_pole(Vector2(x, 370.0), 180.0)
	_pole(Vector2(448.0, 354.0), 228.0)

func _pole(at: Vector2, length: float) -> void:
	var pole := Pole.new()
	pole.size = Vector2(8, length)
	pole.position = at
	add_child(pole)

## Three pairs. Both ends of a pair face the same way, so velocity comes out of
## the exit exactly as it went into the entrance — a portal here redirects where
## you are, never how fast you are going.
func _build_portals() -> void:
	# Diagonals: the bottom corners are the entrances you run into, and they put
	# you out high on the far side of the stage.
	_pair(Vector2(824.0, 456.0), Vector2(172.0, 100.0), COL_RED)
	_pair(Vector2(72.0, 456.0), Vector2(724.0, 100.0), COL_PURPLE)
	# The flat one, floating at mid height on both sides: reachable by jumping off
	# a low shelf or by dropping off the outer end of an upper ledge, and the only
	# pair you cannot simply walk into.
	_pair(Vector2(116.0, 288.0), Vector2(780.0, 288.0), COL_GREEN)

func _pair(a_at: Vector2, b_at: Vector2, accent: Color) -> void:
	var a := _portal(a_at, accent)
	var b := _portal(b_at, accent)
	add_child(a)
	add_child(b)
	a.linked_portal = a.get_path_to(b)
	b.linked_portal = b.get_path_to(a)

func _portal(at: Vector2, accent: Color) -> Portal:
	var portal := Portal.new()
	portal.size = PORTAL_SIZE
	portal.position = at
	portal.facing = Vector2.RIGHT
	portal.accent = accent
	return portal

## Frost creeping up the walls, and a rime line along the underside of every
## platform so the ice reads as the whole room rather than only the floor.
func _draw() -> void:
	super()
	var w := float(ARENA.x * Arena.TILE)
	for i in 3:
		var y := FLOOR_TOP - 8.0 - i * 5.0
		draw_rect(Rect2(0.0, y, w, 2.0), Color(0.49, 0.98, 1.0, 0.10 - i * 0.03))
	for block: Rect2 in platforms():
		draw_rect(Rect2(block.position.x, block.position.y + block.size.y,
			block.size.x, 2.0), Color(0.49, 0.98, 1.0, 0.18))
