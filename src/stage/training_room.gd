extends MatchStage
## Training room: a flat, quiet stage for tuning kits.
##
## Everything here exists to make one question answerable at a time. The layout
## is deliberately plain — one long floor, two low platforms, one wall on each
## side to test wall jumps and Sai's hook against, and a single spring — because
## a stage with opinions makes it impossible to tell whether a number felt wrong
## or the geometry did.
##
## What it adds on top of a normal stage:
##   * **Any hero, instantly.** Seat 0 cycles all twelve with the swap control,
##     bypassing the 3-hero roster entirely. Balance work means comparing kits,
##     and going back to hero select between each one is most of the cost.
##   * **Dummies.** Every other seat is driven by a DummyDriver instead of a
##     device — idle, patrolling, or hopping. They never lose lives for good:
##     the stage puts them back so a session is not interrupted by a round win.
##   * **A cooldown toggle.** `MatchState.unlimited_resources` off means the
##     real economy; on means fire anything as often as you like.
##
## Nothing in here changes how an ability behaves — that would defeat the point.
## It changes only what it costs to try one.

const ARENA: Vector2i = Vector2i(72, 40)
const FLOOR_TOP: float = 496.0
const PLATFORM_TOP: float = 368.0
const HIGH_TOP: float = 256.0

const SPAWNS: Array[Vector2] = [Vector2(280, 472), Vector2(840, 472)]

## Two seats are driven by people, two are targets. They alternate so that each
## player has an ally dummy AND an enemy dummy: at 2v2 seats 0-1 are team 0 and
## 2-3 are team 1, so this puts the two players on OPPOSITE teams (they can
## stomp each other) and gives each of them a teammate to test ally-targeted
## kits on (Saint's Cleanse has nothing to say otherwise).
const HUMAN_SEATS: Array[int] = [0, 2]
const DUMMY_SEATS: Array[int] = [1, 3]

## Every hero, in roster order — the whole point of the room.
var _all_heroes: Array[StringName] = []
## seat -> index into _all_heroes, for the seats a person is driving.
var _hero_index: Dictionary = {}
## seat -> DummyDriver, for the seats this room drives itself.
var _drivers: Dictionary = {}
var _hint: Label
## Edge detection for the room's own keys. Not routed through InputConfig
## because these are development controls, not per-seat gameplay actions —
## binding them per seat would put them in everyone's namespace for no reason.
var _f5_held: bool = false
var _f6_held: bool = false
var _f7_held: bool = false

const BACKDROP: Array[Color] = [
	Color(0.06, 0.06, 0.10), Color(0.09, 0.09, 0.15),
	Color(0.12, 0.12, 0.19), Color(0.15, 0.14, 0.23),
]

func stage_id() -> StringName: return &"training_room"
func arena_size() -> Vector2i: return ARENA
func spawns() -> Array[Vector2]: return SPAWNS
func sky_bands() -> Array[Color]: return BACKDROP
func horizon() -> float: return FLOOR_TOP
func ground_fill() -> Color: return Color(0.05, 0.05, 0.08)
func cap_color() -> Color: return Color(0.45, 0.45, 0.60)

## Flat floor, two platforms at known heights, and the sealed box. The platform
## heights are the reach numbers from docs/MAPS.md: 128px above the floor is a
## held jump, 240px is jump-plus-dash — so "can this kit get up there" has a
## right answer rather than a feel.
func arena_blocks() -> Array[Rect2]:
	var blocks := Arena.sealed_box(ARENA)
	blocks.append(Rect2(16.0, FLOOR_TOP, 1120.0, 128.0))
	blocks.append(Rect2(400.0, PLATFORM_TOP, 160.0, 16.0))
	blocks.append(Rect2(624.0, HIGH_TOP, 160.0, 16.0))
	return blocks

## One spring and one pole: enough to check that a kit interacts with terrain at
## all (a slept body bouncing, a dash refill) without the stage being a course.
func build_terrain() -> void:
	var spring := JumpSpring.new()
	spring.size = Vector2(64.0, 16.0)
	spring.position = Vector2(1000.0, FLOOR_TOP - 8.0)
	spring.launch_velocity = Vector2(0, -820)
	add_child(spring)

	var pole := Pole.new()
	pole.size = Vector2(8, 176)
	pole.position = Vector2(160.0, 380.0)
	add_child(pole)

func _ready() -> void:
	# Before super(): MatchStage seats itself from the format, and this room is
	# always two people plus two targets regardless of what the lobby was set
	# to — which is also what makes booting this scene straight with F6 work.
	GameManager.team_size = 2
	super()
	_all_heroes = GameManager.roster_ids()

	# The second player takes the first pad. Assigned here rather than claimed
	# in the lobby so the room is self-contained: one keyboard and one
	# controller is the common bench setup, and seat 2's default binding would
	# otherwise be the *second* pad.
	InputConfig.assign_device(HUMAN_SEATS[0], InputConfig.Device.KBM)
	InputConfig.assign_device(HUMAN_SEATS[1], InputConfig.Device.PAD, 0)
	for seat: int in HUMAN_SEATS:
		if seat >= players.size():
			continue
		_hero_index[seat] = maxi(_all_heroes.find(MatchState.active_hero(seat)), 0)
		players[seat].input_source = _human_input(seat)

	for seat: int in DUMMY_SEATS:
		if seat >= players.size():
			continue
		var driver := DummyDriver.new()
		# Standing still by default: a still target is the baseline for
		# measuring a hitbox or a range, and anything that moves adds a
		# variable to whatever is being tuned. F6 sets them walking.
		driver.mode = DummyDriver.Mode.IDLE
		# Staggered so that once they DO move they do not travel as one block.
		driver.phase = float(seat) * 0.7
		_drivers[seat] = driver
		players[seat].input_source = driver.poll
	MatchState.life_lost.connect(_on_dummy_life_lost)
	# On its own CanvasLayer, not as a child of the stage: a Label parented to a
	# Node2D lives in world space and rides the camera, which put this straight
	# through the HUD. Bottom-left, where neither the HUD nor the stage's own
	# debug readout goes.
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, -104)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_hint)

func _exit_tree() -> void:
	# The toggle belongs to the room, not the session: a match started after
	# this must never inherit free ultimates.
	MatchState.unlimited_resources = false

## Dummies are targets, not opponents — a stomped one gets its life straight
## back, so a tuning session is never interrupted by a round ending.
func _on_dummy_life_lost(player_id: int, hero_id: StringName, _left: int) -> void:
	if player_id == 0:
		return
	MatchState.restore_lives(player_id, hero_id)

## A human seat's input, with SWAP intercepted. The room owns that button here:
## left alone, Player.try_swap would rotate the seat's three-hero roster on the
## same press this uses to walk all twelve, and both would fire.
##
## Reusing input_source rather than reading the button in _physics_process is
## what makes that reliable — the interception happens at the one place the
## body actually reads its intent, so there is no ordering question about which
## saw the press first.
func _human_input(seat: int) -> Callable:
	return func(body: Player) -> InputFrame:
		var frame := InputConfig.poll(seat, body)
		if frame.swap_pressed:
			frame.swap_pressed = false
			_cycle_hero(seat)
		return frame

## Step a seat to the next hero in the FULL roster. equip_hero is the same call
## a real swap makes, so the hero arrives fully wired; only MatchState's
## three-hero roster check is being stepped around.
func _cycle_hero(seat: int) -> void:
	if seat >= players.size() or players[seat].stun_remaining > 0.0:
		return
	_hero_index[seat] = wrapi(int(_hero_index.get(seat, 0)) + 1, 0, _all_heroes.size())
	players[seat].equip_hero(_all_heroes[_hero_index[seat]])

func _physics_process(delta: float) -> void:
	super(delta)
	if Input.is_physical_key_pressed(KEY_F5) and not _f5_held:
		MatchState.unlimited_resources = not MatchState.unlimited_resources
	_f5_held = Input.is_physical_key_pressed(KEY_F5)
	if Input.is_physical_key_pressed(KEY_F6) and not _f6_held:
		for seat in _drivers:
			(_drivers[seat] as DummyDriver).cycle()
	_f6_held = Input.is_physical_key_pressed(KEY_F6)
	if Input.is_physical_key_pressed(KEY_F7) and not _f7_held:
		_reset_bodies()
	_f7_held = Input.is_physical_key_pressed(KEY_F7)
	_update_hint()

func _reset_bodies() -> void:
	for i in players.size():
		players[i].respawn_at(spawn_for(i))

func _update_hint() -> void:
	var mode := "?"
	if not _drivers.is_empty():
		mode = (_drivers[_drivers.keys()[0]] as DummyDriver).label()
	var who := ""
	for seat: int in HUMAN_SEATS:
		if seat >= players.size():
			continue
		# Numbered by SEAT, not by which of the two humans this is — the HUD and
		# the debug readout both label these bodies P1 and P3, and a hint that
		# called them P1 and P2 would be describing different players.
		who += "P%d (%s): %s\n" % [seat + 1, InputConfig.device_label(seat),
			String(_all_heroes[int(_hero_index.get(seat, 0))]).to_upper()]
	_hint.text = "TRAINING ROOM\n" + who \
		+ "swap: next hero (all %d, per player)\n" % _all_heroes.size() \
		+ "F5 cooldowns: %s\n" % ("OFF - free" if MatchState.unlimited_resources else "on") \
		+ "F6 dummies: %s\n" % mode \
		+ "F7 reset positions   ·   F3 reach overlay"
