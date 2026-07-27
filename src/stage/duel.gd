extends MatchStage
## Rooftop Rumble (DESIGN 6.3): city rooftops at dusk. Layout, terrain and
## palette only — MatchStage owns the seats, the round loop and the overlay.

## Sized Large (DESIGN 6.1: ~72x40) rather than the Small a 1v1 calls for — this
## is also the movement test bench, and momentum needs runway: a capped run
## crosses a Small stage in under two seconds, which leaves nothing to actually
## chain b-hops or wall jumps across.
const ARENA: Vector2i = Vector2i(72, 40)
## Opposite rooftops (DESIGN 6.1: team spawns on opposite sides).
const SPAWNS: Array[Vector2] = [Vector2(200, 408), Vector2(952, 408)]
## The rooftop line; sky above it, dark city below.
const HORIZON: float = 432.0
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

## Two facing rooftops over a long open street, stepping platforms between them,
## a contested high slab, and a 64px shaft under that slab. The shaft is narrow
## on purpose — bodies are 22px wide, so 64px is close enough that two players
## climbing it meet, which is what makes wall-jump duels (DESIGN 3.4) happen
## deliberately rather than by accident.
##
## The street runs the full width with nothing on it: b-hop chains need a runway
## with no geometry in the arc, and that is most of why the stage is this big.
##
## Rooftops are slabs with air beneath rather than solid buildings: it keeps the
## whole street open, which is what a stomp game needs. There is nowhere to fall
## to — the box is sealed (DESIGN 6.1).
func arena_blocks() -> Array[Rect2]:
	var t := float(Arena.TILE)
	var blocks := Arena.sealed_box(ARENA)
	blocks.append_array([
		Rect2(96.0, 432.0, 208.0, t),    # left rooftop (spawn)
		Rect2(848.0, 432.0, 208.0, t),   # right rooftop (spawn)
		Rect2(256.0, 336.0, 128.0, t),   # left upper ledge
		Rect2(768.0, 336.0, 128.0, t),   # right upper ledge
		Rect2(496.0, 288.0, 160.0, t),   # contested high slab, spans the shaft
		Rect2(512.0, 304.0, t, 160.0),   # shaft wall, inner face at x=528
		Rect2(592.0, 304.0, t, 160.0),   # shaft wall, inner face at x=592
		Rect2(384.0, 496.0, 96.0, t),    # mid stepping platform
		Rect2(672.0, 496.0, 96.0, t),    # mid stepping platform
		Rect2(176.0, 544.0, 96.0, t),    # awning, street level
		Rect2(880.0, 544.0, 96.0, t),    # awning, street level
	])
	return blocks

## Exactly the set DESIGN 6.3 calls for: antennas to grab, awnings to bounce
## off, and one wind corridor between the buildings.
##
## Every element is placed clear of the open street, because the street is the
## b-hop runway and putting anything on it would take away the one part of the
## stage that is deliberately empty.
func build_terrain() -> void:
	# Antennas: a pole on each rooftop. The movement reset button, parked exactly
	# where a player who has just been chased across the map wants one.
	for x: float in [160.0, 992.0]:
		var pole := Pole.new()
		pole.size = Vector2(8, 120)
		pole.position = Vector2(x, 372)
		add_child(pole)

	# Awnings: springs on the low ledges, narrow enough to be aimed at rather
	# than fallen onto.
	for x: float in [224.0, 928.0]:
		var spring := JumpSpring.new()
		spring.size = Vector2(64, 16)
		spring.position = Vector2(x, 536)
		spring.launch_velocity = Vector2(0, -760)
		add_child(spring)

	# Wind corridor: an updraft in the shaft between the buildings. It does not
	# beat gravity on its own — it makes the shaft climbable with wall jumps
	# rather than climbing it for you.
	var wind := WindZone.new()
	wind.size = Vector2(64, 160)
	wind.position = Vector2(560, 384)
	wind.force = Vector2(0, -420)
	add_child(wind)
