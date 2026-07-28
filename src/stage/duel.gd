extends MatchStage
## Rooftop Rumble (DESIGN 6.3): city rooftops at dusk. Layout, terrain and
## palette only — MatchStage owns the seats, the round loop and the overlay.
##
## Rebuilt from a layout sketch. One wide rooftop fills the middle of the stage
## and a channel runs down each side of it to street level. Everything about the
## stage follows from that shape: the roof is the runway and the fight, the
## channels are where you end up when you lose it, and the only quick way back
## from a channel is a **one-way** teleporter to the far top corner.
##
## The one-way rule is what makes falling in cost something. A pair you could
## ride in both directions would turn the channels into a free elevator; as it
## is, going down is a mistake and coming back puts you on the opposite side of
## the stage from where you fell, with the whole roof between you and your fight.
##
## Sealed, and nothing here can take a life (DESIGN 6.1, CLAUDE.md 1-2).

## Large (DESIGN 6.1: ~72x40). This is also the movement test bench, and momentum
## needs runway — the roof below is 800px of it.
const ARENA: Vector2i = Vector2i(72, 40)
const STREET_TOP: float = 624.0

## The rooftop: one solid mass from street to roof, with a channel either side.
const ROOF_TOP: float = 368.0
const ROOF_LEFT: float = 176.0
const ROOF_RIGHT: float = 976.0

## Platform tiers above the roof, each within a held jump (92px) of the one that
## feeds it. Bodies stand 24px above a surface.
const TIER_MID: float = 288.0     ## side platforms overhanging the roof edges
const TIER_CENTRE: float = 224.0  ## the contested middle
const TIER_UPPER: float = 144.0   ## the high pair

## Opposite ends of the roof.
const SPAWNS: Array[Vector2] = [Vector2(280, 344), Vector2(872, 344)]

## The roof spring. Wider than the platform above it, so its outer 48px on each
## side launch clear while the middle bumps the underside — approach matters, and
## springs keep horizontal speed precisely so that it can.
const SPRING_SPAN: float = 192.0
const SPRING_LAUNCH: Vector2 = Vector2(0, -820)
## Wall springs, mounted mid-height on both side walls: they fling you across the
## roof rather than up it, which is what a body climbing out of a channel needs.
const WALL_SPRING_LAUNCH: float = 760.0

const PORTAL_SIZE: Vector2 = Vector2(40, 56)
const COL_RED: Color = Color(0.93, 0.42, 0.42)
const COL_GREEN: Color = Color(0.55, 0.83, 0.51)

## The rooftop line; sky above it, dark city below.
const HORIZON: float = 368.0
const SKY: Array[Color] = [
	Color(0.10, 0.06, 0.19), Color(0.16, 0.11, 0.29),
	Color(0.23, 0.18, 0.39), Color(0.42, 0.18, 0.36),
]

var _ground_tex: Texture2D = load("res://assets/stages/tile_ground.png")

func stage_id() -> StringName: return &"rooftop_rumble"
func arena_size() -> Vector2i: return ARENA
func spawns() -> Array[Vector2]: return SPAWNS
func sky_bands() -> Array[Color]: return SKY
func horizon() -> float: return HORIZON
func ground_texture() -> Texture2D: return _ground_tex

## Every platform above the roof, listed once. Symmetric about x=576.
func platforms() -> Array[Rect2]:
	return [
		Rect2(288.0, TIER_UPPER, 160.0, 16.0),   # upper left
		Rect2(704.0, TIER_UPPER, 160.0, 16.0),   # upper right
		Rect2(528.0, TIER_CENTRE, 96.0, 16.0),   # the contested middle
		Rect2(176.0, TIER_MID, 160.0, 16.0),     # mid left
		Rect2(816.0, TIER_MID, 160.0, 16.0),     # mid right
	]

## The roof, the platforms above it, and the sealed box. The channels are simply
## where the roof is not: 160px wide, walled on both sides, which makes them
## climbable by wall jump (a shaft needs two facing faces) but slowly.
func arena_blocks() -> Array[Rect2]:
	var blocks := Arena.sealed_box(ARENA)
	blocks.append(Rect2(ROOF_LEFT, ROOF_TOP, ROOF_RIGHT - ROOF_LEFT,
		STREET_TOP - ROOF_TOP))
	blocks.append_array(platforms())
	return blocks

func build_terrain() -> void:
	_build_springs()
	_build_portals()

func _build_springs() -> void:
	var roof := JumpSpring.new()
	roof.size = Vector2(SPRING_SPAN, 16.0)
	roof.position = Vector2(576.0, ROOF_TOP - 8.0)
	roof.launch_velocity = SPRING_LAUNCH
	add_child(roof)

	# One on each side wall, spanning the height between the mid and upper tiers.
	# They launch along their own axis now, so they keep your fall and replace
	# only the sideways part: stepping into one mid-drop throws you out over the
	# roof still descending, which is the recovery the channels need.
	for side: float in [-1.0, 1.0]:
		var wall := JumpSpring.new()
		wall.size = Vector2(16.0, 112.0)
		wall.position = Vector2(24.0 if side > 0.0 else 1128.0, 224.0)
		wall.launch_velocity = Vector2(WALL_SPRING_LAUNCH * side, 0.0)
		add_child(wall)

## Two ONE-WAY pairs, both diagonal and both upward: only the bottom end carries
## a link, so the top end is an arrival pad that does nothing when touched.
##
## Colour says which goes where, and the diagonal says why it is worth taking —
## you come out of a channel on the far side of the stage, not the side you fell
## down.
func _build_portals() -> void:
	_one_way(Vector2(96.0, 572.0), Vector2(952.0, 56.0), COL_RED)
	_one_way(Vector2(1056.0, 572.0), Vector2(200.0, 56.0), COL_GREEN)

func _one_way(from_at: Vector2, to_at: Vector2, accent: Color) -> void:
	var entrance := _portal(from_at, accent)
	var arrival := _portal(to_at, accent)
	add_child(entrance)
	add_child(arrival)
	# Only the entrance is linked. The arrival end never sends anyone anywhere,
	# which is the whole of "one-way" — no flag needed, and Portal already treats
	# an empty link as "do nothing".
	entrance.linked_portal = entrance.get_path_to(arrival)

func _portal(at: Vector2, accent: Color) -> Portal:
	var portal := Portal.new()
	portal.size = PORTAL_SIZE
	portal.position = at
	portal.facing = Vector2.RIGHT
	portal.accent = accent
	return portal

## Roof edge lighting and a hint of depth down each channel, so the drop reads
## as a drop from up on the roof.
func _draw() -> void:
	super()
	var depth := STREET_TOP - ROOF_TOP
	for channel: Rect2 in [Rect2(16.0, ROOF_TOP, ROOF_LEFT - 16.0, depth),
			Rect2(ROOF_RIGHT, ROOF_TOP, 1136.0 - ROOF_RIGHT, depth)]:
		draw_rect(channel, Color(0.0, 0.0, 0.0, 0.25))
	for x: float in [ROOF_LEFT, ROOF_RIGHT - 3.0]:
		draw_rect(Rect2(x, ROOF_TOP, 3.0, depth), Color(0.63, 0.24, 0.47, 0.35))
