extends MatchStage
## Training room: one person, three bots, every hero, for tuning kits.
##
## The layout is deliberately plain — one long floor, two platforms at known
## reach heights, one wall each side, a spring and a pole — because a stage with
## opinions makes it impossible to tell whether a number felt wrong or the
## geometry did.
##
## What it changes about a normal stage:
##   * **One human, three bots.** Seat 0 is the keyboard; the other three are
##     driven by DummyDriver. Two patrol and hop occasionally, one stands
##     still — a still target is the baseline for measuring a hitbox, the
##     movers are for aim. Bots never lose lives for good.
##   * **Any hero, instantly.** Swap cycles ALL twelve, not a 3-hero roster.
##   * **Free ultimates, always** — no budget, no gap — and **F5 toggles
##     ability cooldowns**. Nothing about how a kit behaves changes; only what
##     it costs to try one.

const HUMAN_SEAT: int = 0
## Who does what. The still bot is the ALLY (seat 1 at 2v2) standing near the
## player: it doubles as the target for ally-cast kits (Saint's Cleanse), and a
## test subject you have to chase is a worse baseline than one that waits. The
## two enemies are the movers.
const IDLE_SEATS: Array[int] = [1]
const MOVER_SEATS: Array[int] = [2, 3]

const ARENA: Vector2i = Vector2i(72, 40)
const FLOOR_TOP: float = 496.0
const PLATFORM_TOP: float = 368.0
const HIGH_TOP: float = 256.0

const SPAWNS: Array[Vector2] = [Vector2(280, 472), Vector2(840, 472)]

## Every hero, in roster order — the whole point of the room.
var _all_heroes: Array[StringName] = []
var _hero_index: int = 0
## seat -> DummyDriver, for the three seats this room drives itself.
var _drivers: Dictionary = {}
## F6 freezes the movers (everything idle) and unfreezes them again.
var _movers_frozen: bool = false
var _hint: Label
## Edge detection for the room's own keys. Not routed through InputConfig
## because these are development controls, not per-seat gameplay actions.
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
	# always one person plus three bots regardless of what the lobby was set
	# to — which is also what makes booting the scene straight with F6 work.
	GameManager.team_size = 2
	super()
	_all_heroes = GameManager.roster_ids()
	_hero_index = maxi(_all_heroes.find(MatchState.active_hero(HUMAN_SEAT)), 0)

	# The room owns its one device: whoever opened it is on the keyboard.
	# Assigned rather than inherited from the lobby, so the room works the same
	# whether it was entered from there or booted directly.
	InputConfig.assign_device(HUMAN_SEAT, InputConfig.Device.KBM)
	players[HUMAN_SEAT].input_source = _human_input

	for seat in range(1, players.size()):
		var driver := DummyDriver.new()
		driver.mode = DummyDriver.Mode.IDLE if seat in IDLE_SEATS else DummyDriver.Mode.HOP
		# Staggered so the two movers do not travel as one block.
		driver.phase = float(seat) * 0.9
		_drivers[seat] = driver
		players[seat].input_source = driver.poll

	# Ultimates are free the whole time the room is open — no budget, no gap.
	# Cooldowns start REAL so the first impression of a kit is honest; F5 frees
	# them.
	MatchState.free_ultimates = true
	MatchState.free_cooldowns = false
	MatchState.life_lost.connect(_on_bot_life_lost)

	# The hint lives on its own CanvasLayer: a Label parented to the stage sits
	# in world space and rides the camera straight through the HUD.
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
	# The switches belong to the room, not the session: a match started after
	# this must never inherit free anything.
	MatchState.free_cooldowns = false
	MatchState.free_ultimates = false

## Bots are targets, not opponents — a stomped one gets its life straight back,
## so a tuning session is never interrupted by a round win.
func _on_bot_life_lost(player_id: int, hero_id: StringName, _left: int) -> void:
	if player_id == HUMAN_SEAT:
		return
	MatchState.restore_lives(player_id, hero_id)

## The human's input, with SWAP intercepted. The room owns that button: left
## alone, Player.try_swap would rotate the seat's three-hero roster on the same
## press this uses to walk all twelve, and both would fire. Intercepting at the
## one place the body reads its intent removes the ordering question.
func _human_input(body: Player) -> InputFrame:
	var frame := InputConfig.poll(HUMAN_SEAT, body)
	if frame.swap_pressed:
		frame.swap_pressed = false
		_cycle_hero()
	return frame

## Step to the next hero in the FULL roster. equip_hero is the same call a real
## swap makes, so the hero arrives fully wired; only MatchState's three-hero
## roster check is being stepped around.
func _cycle_hero() -> void:
	if players[HUMAN_SEAT].stun_remaining > 0.0:
		return
	_hero_index = wrapi(_hero_index + 1, 0, _all_heroes.size())
	players[HUMAN_SEAT].equip_hero(_all_heroes[_hero_index])

func _physics_process(delta: float) -> void:
	super(delta)
	if Input.is_physical_key_pressed(KEY_F5) and not _f5_held:
		MatchState.free_cooldowns = not MatchState.free_cooldowns
	_f5_held = Input.is_physical_key_pressed(KEY_F5)
	if Input.is_physical_key_pressed(KEY_F6) and not _f6_held:
		_movers_frozen = not _movers_frozen
		for seat in MOVER_SEATS:
			if _drivers.has(seat):
				(_drivers[seat] as DummyDriver).mode = \
					DummyDriver.Mode.IDLE if _movers_frozen else DummyDriver.Mode.HOP
	_f6_held = Input.is_physical_key_pressed(KEY_F6)
	if Input.is_physical_key_pressed(KEY_F7) and not _f7_held:
		_reset_bodies()
	_f7_held = Input.is_physical_key_pressed(KEY_F7)
	_update_hint()

func _reset_bodies() -> void:
	for i in players.size():
		players[i].respawn_at(spawn_for(i))

func _update_hint() -> void:
	_hint.text = "TRAINING ROOM   %s\n" % String(_all_heroes[_hero_index]).to_upper() \
		+ "swap (RMB): next hero (all %d)   ·   ultimates always free\n" % _all_heroes.size() \
		+ "F5 ability cooldowns: %s\n" % ("OFF - free" if MatchState.free_cooldowns else "ON - real") \
		+ "F6 moving bots: %s   ·   F7 reset positions   ·   F3 reach overlay" \
			% ("frozen" if _movers_frozen else "walking + hopping")
