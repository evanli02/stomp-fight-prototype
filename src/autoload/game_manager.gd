extends Node
## GameManager — match lifecycle FSM: LOBBY -> HERO_SELECT -> STAGE_SELECT ->
## ROUND_ACTIVE -> ROUND_RESULTS -> (loop | MATCH_RESULTS).
## Owns the seeded RNG (determinism posture, IMPLEMENTATION.md #9) and the hero
## roster registry. Holds no scene references: arenas listen to signals from
## here and from MatchState, never the other way round.

enum Phase { LOBBY, HERO_SELECT, STAGE_SELECT, ROUND_ACTIVE, ROUND_RESULTS, MATCH_RESULTS }

signal phase_changed(phase: Phase)
signal round_started(round_index: int)
signal match_won(team_id: int)

## Registered heroes: id -> HeroData resource path. Extend via SKILL.md "Add a hero".
const HERO_ROSTER: Dictionary = {
	&"deadeye": "res://src/heroes/resources/deadeye.tres",
	&"fei": "res://src/heroes/resources/fei.tres",
	&"mason": "res://src/heroes/resources/mason.tres",
	&"cerebelle": "res://src/heroes/resources/cerebelle.tres",
	&"sai": "res://src/heroes/resources/sai.tres",
	&"slip": "res://src/heroes/resources/slip.tres",
	&"terra": "res://src/heroes/resources/terra.tres",
	&"kid": "res://src/heroes/resources/kid.tres",
	&"voodoo": "res://src/heroes/resources/voodoo.tres",
	&"saint": "res://src/heroes/resources/saint.tres",
	&"vesper": "res://src/heroes/resources/vesper.tres",
	&"siku": "res://src/heroes/resources/siku.tres",
}

## Registered stages. Extend via SKILL.md "Add a stage"; order here is the order
## they appear on the select screen.
##
## Name, blurb and features live here rather than on the stage script so the
## select screen can describe a stage without instantiating it — instantiating
## one builds its geometry, spawns two bodies and starts a match, which is not
## something a menu should be doing to draw a card. The stage script reads its
## own name back out of here (MatchStage.stage_name), so there is still one
## source of truth.
##
## "preview" is a visual-only miniature for the select screen: the stage's
## pixel size, its terrain silhouette, and its terrain elements as coloured
## marks (STYLE_GUIDE colour-coding: green springs, pale-blue ice, portals in
## their pair colours, grey poles). Hand-kept against each stage's layout
## constants — a preview is a picture of the stage, not the stage, and drawing
## a card must never build one.
const STAGE_ROSTER: Dictionary = {
	&"rooftop_rumble": {
		"scene": "res://src/stage/duel.tscn",
		"name": "Rooftop Rumble",
		"blurb": "Open street, high slab, one narrow shaft.",
		"features": "poles · springs · updraft",
		"accent": Color(0.63, 0.24, 0.47),
		"preview": {
			"size": Vector2(1152, 640),
			"blocks": [
				Rect2(0, 624, 1152, 16), Rect2(0, 0, 1152, 16),
				Rect2(0, 0, 16, 640), Rect2(1136, 0, 16, 640),
				Rect2(176, 368, 800, 256),
				Rect2(320, 144, 96, 16), Rect2(736, 144, 96, 16),
				Rect2(528, 224, 96, 16),
				Rect2(144, 288, 96, 16), Rect2(912, 288, 96, 16),
			],
			"marks": [
				{"rect": Rect2(416, 352, 96, 16), "color": Color(0.4, 0.85, 0.45)},
				{"rect": Rect2(640, 352, 96, 16), "color": Color(0.4, 0.85, 0.45)},
				{"rect": Rect2(16, 136, 24, 176), "color": Color(0.4, 0.85, 0.45)},
				{"rect": Rect2(1112, 136, 24, 176), "color": Color(0.4, 0.85, 0.45)},
				{"rect": Rect2(16, 560, 160, 64), "color": Color(0.93, 0.42, 0.42)},
				{"rect": Rect2(764, 60, 40, 56), "color": Color(0.93, 0.42, 0.42)},
				{"rect": Rect2(976, 560, 160, 64), "color": Color(0.55, 0.83, 0.51)},
				{"rect": Rect2(348, 60, 40, 56), "color": Color(0.55, 0.83, 0.51)},
				{"rect": Rect2(572, 88, 8, 80), "color": Color(0.6, 0.6, 0.7)},
			],
		},
	},
	&"sunken_court": {
		"scene": "res://src/stage/sunken_court.tscn",
		"name": "Sunken Court",
		"blurb": "Two mesas over a sprung trench you cannot climb out of.",
		"features": "springs - poles - one high platform",
		"accent": Color(0.95, 0.55, 0.28),
		"preview": {
			"size": Vector2(896, 512),
			"blocks": [
				Rect2(0, 496, 896, 16), Rect2(0, 0, 896, 16),
				Rect2(0, 0, 16, 512), Rect2(880, 0, 16, 512),
				Rect2(16, 368, 272, 128), Rect2(608, 368, 272, 128),
				Rect2(288, 272, 320, 16),
			],
			"marks": [
				{"rect": Rect2(288, 484, 320, 12), "color": Color(0.4, 0.85, 0.45)},
				{"rect": Rect2(116, 120, 8, 160), "color": Color(0.6, 0.6, 0.7)},
				{"rect": Rect2(772, 120, 8, 160), "color": Color(0.6, 0.6, 0.7)},
			],
		},
	},
	&"cryo_lab": {
		"scene": "res://src/stage/cryo_lab.tscn",
		"name": "Cryo Lab",
		"blurb": "Every surface is ice. Three portals, no hazards.",
		"features": "all ice - 3 portal pairs - poles",
		"accent": Color(0.18, 0.89, 0.90),
		"preview": {
			"size": Vector2(896, 512),
			"blocks": [
				Rect2(0, 496, 896, 16), Rect2(0, 0, 896, 16),
				Rect2(0, 0, 16, 512), Rect2(880, 0, 16, 512),
				Rect2(352, 96, 192, 16),
				Rect2(128, 160, 160, 16), Rect2(608, 160, 160, 16),
				Rect2(288, 224, 320, 16),
				Rect2(320, 352, 64, 16), Rect2(512, 352, 64, 16),
				Rect2(16, 416, 160, 16), Rect2(720, 416, 160, 16),
			],
			"marks": [
				{"rect": Rect2(16, 490, 864, 6), "color": Color(0.49, 0.98, 1.0)},
				{"rect": Rect2(260, 280, 8, 160), "color": Color(0.6, 0.6, 0.7)},
				{"rect": Rect2(628, 280, 8, 160), "color": Color(0.6, 0.6, 0.7)},
				{"rect": Rect2(444, 240, 8, 200), "color": Color(0.6, 0.6, 0.7)},
				{"rect": Rect2(804, 428, 40, 56), "color": Color(0.93, 0.42, 0.42)},
				{"rect": Rect2(152, 72, 40, 56), "color": Color(0.93, 0.42, 0.42)},
				{"rect": Rect2(52, 428, 40, 56), "color": Color(0.60, 0.48, 0.86)},
				{"rect": Rect2(704, 72, 40, 56), "color": Color(0.60, 0.48, 0.86)},
				{"rect": Rect2(96, 292, 40, 56), "color": Color(0.55, 0.83, 0.51)},
				{"rect": Rect2(760, 292, 40, 56), "color": Color(0.55, 0.83, 0.51)},
			],
		},
	},
}

## How long the results banner holds before the next round. Presentation pacing,
## not a feel number.
const RESULTS_TIME: float = 2.5

var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.LOBBY

## Lobby config
var team_size: int = 1          # 1, 2, or 3
var best_of: int = 3            # 1, 3, or 5

## Two teams, always (DESIGN 2.1). Everything downstream — seat count, which
## side a seat spawns on, how many rows hero select draws — is derived from
## team_size rather than assumed, so setting it is the whole of "play 2v2".
const TEAMS: int = 2

var round_index: int = 0
var coinflip_winner_team: int = 0
## The stage the current round is on. Stages booted standalone never change it,
## which is why it has a sensible default rather than being empty.
var current_stage: StringName = &"rooftop_rumble"
var _results_remaining: float = 0.0
var _hero_cache: Dictionary = {}
## Whether this match routes through the stage-select screen between rounds.
## Off for harnesses and F6 boots, which have no shell to show one.
var _stage_select_enabled: bool = false

func _ready() -> void:
	rng.seed = hash("overstomp")  # TODO(M6): seed per match, share for netcode
	# Every feel number and every harness expectation is written against a 60 Hz
	# gameplay tick (IMPLEMENTATION.md 9). project.godot states it explicitly,
	# but the editor prunes settings that match the engine default on save, so
	# the rule is asserted here where nothing can quietly drop it.
	assert(Engine.physics_ticks_per_second == 60,
		"Overstomp requires a 60 Hz physics tick, got %d" % Engine.physics_ticks_per_second)

## Cooldowns tick only while a round is actually being played, so they do not
## burn down behind a results banner or a hero-select screen.
func _physics_process(delta: float) -> void:
	if phase == Phase.ROUND_ACTIVE:
		MatchState.tick_cooldowns(delta)
	elif phase == Phase.ROUND_RESULTS and _results_remaining > 0.0:
		_results_remaining -= delta
		if _results_remaining <= 0.0:
			_advance_after_results()

#region Hero registry
## HeroData for an id, loaded once. Returns null for an unknown id rather than
## asserting: debug scenes run bodies with hero ids that are not in the roster.
func hero_data(hero_id: StringName) -> HeroData:
	if _hero_cache.has(hero_id):
		return _hero_cache[hero_id]
	if not HERO_ROSTER.has(hero_id):
		return null
	var data := load(HERO_ROSTER[hero_id]) as HeroData
	_hero_cache[hero_id] = data
	return data

func roster_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in HERO_ROSTER:
		out.append(id)
	return out
#endregion

#region Stage registry
func stage_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in STAGE_ROSTER:
		out.append(id)
	return out

## One field of a registered stage, or the fallback for an unknown id. Debug
## scenes run stages that were never registered, so this does not assert.
func stage_info(stage_id: StringName, key: String, fallback: Variant = "") -> Variant:
	if not STAGE_ROSTER.has(stage_id):
		return fallback
	return STAGE_ROSTER[stage_id].get(key, fallback)

func stage_scene(stage_id: StringName) -> PackedScene:
	var path: String = stage_info(stage_id, "scene", "")
	if path.is_empty():
		return null
	return load(path) as PackedScene
#endregion

#region Match flow
func set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)

func begin_hero_select() -> void:
	## Rosters are not known yet, so nothing is registered until picks land.
	MatchState.clear_players()
	MatchState.round_wins.clear()
	round_index = 0
	set_phase(Phase.HERO_SELECT)

## Begin a match from an already-picked set of rosters: player_id -> hero ids.
## Hero select supplies these; arenas run standalone by calling this themselves.
##
## `use_stage_select` is off by default so that a stage booted with F6, and every
## harness, still drops straight into a round — they are already sitting in a
## stage, so asking them which one to load would deadlock. The shell turns it on.
func start_match(rosters: Dictionary, teams: Dictionary,
		use_stage_select: bool = false) -> void:
	MatchState.clear_players()
	MatchState.round_wins.clear()
	round_index = 0
	for pid in rosters:
		MatchState.register_player(pid, teams[pid], rosters[pid])
	coinflip_winner_team = coinflip(0, 1)
	_stage_select_enabled = use_stage_select
	if use_stage_select:
		begin_stage_select()
	else:
		start_round()

## Run the same match again from round one: same rosters, same teams, same stage,
## score wiped. Used by the pause menu, and deliberately NOT a fresh start_match
## call from the caller's side — that would drop _stage_select_enabled and
## quietly stop routing later rounds through stage select.
func restart_match() -> void:
	var rosters := {}
	var teams := {}
	for pid in MatchState.players:
		var ids: Array[StringName] = []
		for hero in MatchState.roster(pid):
			ids.append(hero)
		rosters[pid] = ids
		teams[pid] = MatchState.team_of(pid)
	if rosters.is_empty():
		return
	var routed := _stage_select_enabled
	start_match(rosters, teams, false)   # straight back in, on the stage we are on
	_stage_select_enabled = routed

## Back to the front of the session. Rosters go with it: the lobby is where seats
## are claimed, and a stale roster would seat players who never sat down.
func return_to_lobby() -> void:
	MatchState.clear_players()
	MatchState.round_wins.clear()
	MatchState.last_round_loser_team = -1
	round_index = 0
	_stage_select_enabled = false
	set_phase(Phase.LOBBY)

func begin_stage_select() -> void:
	set_phase(Phase.STAGE_SELECT)

## Lock in the stage for the round about to start (DESIGN 2.2). An unknown id
## leaves the previous stage standing rather than loading nothing.
func choose_stage(stage_id: StringName) -> void:
	if STAGE_ROSTER.has(stage_id):
		current_stage = stage_id
	start_round()

## An online match without the select screens: every seat gets a fallback trio
## and the match starts on the current stage. The rosters come from the same
## table a stage booted standalone uses, so the trios are the ones every debug
## path has always produced.
func start_quick_match() -> void:
	var rosters := {}
	for seat in seat_count():
		var ids: Array[StringName] = []
		for h in MatchStage.SEAT_ROSTERS[seat % MatchStage.SEAT_ROSTERS.size()]:
			ids.append(h)
		rosters[seat] = ids
	start_match(rosters, seat_teams())

func start_round() -> void:
	MatchState.reset_round()
	set_phase(Phase.ROUND_ACTIVE)
	round_started.emit(round_index)

## Called by MatchState.round_won listeners (the arena owns the bodies, so it
## decides when the round is visually over and hands control back here).
func end_round() -> void:
	if phase != Phase.ROUND_ACTIVE:
		return
	set_phase(Phase.ROUND_RESULTS)
	_results_remaining = RESULTS_TIME

func _advance_after_results() -> void:
	var needed := best_of / 2 + 1
	for team in MatchState.round_wins:
		if MatchState.wins_for(team) >= needed:
			set_phase(Phase.MATCH_RESULTS)
			match_won.emit(team)
			return
	round_index += 1
	if _stage_select_enabled:
		begin_stage_select()
	else:
		start_round()

#region Format
## Total local seats in the current format: 2 for 1v1, 6 for 3v3.
func seat_count() -> int:
	return TEAMS * team_size

## Seats are allocated in blocks, not interleaved: seats 0..team_size-1 are team
## 0 and the rest are team 1. Blocks keep "which side do I spawn on" a division
## instead of a lookup, and keep a seat's team stable when the format changes.
func team_of_seat(seat: int) -> int:
	return seat / maxi(team_size, 1)

## Where a seat sits within its own team — used to space teammates apart at the
## spawn and to pick which of them holds the stage cursor.
func index_in_team(seat: int) -> int:
	return seat % maxi(team_size, 1)

## Seat -> team map for the whole format, in the shape start_match wants.
func seat_teams() -> Dictionary:
	var out := {}
	for seat in seat_count():
		out[seat] = team_of_seat(seat)
	return out

## Which seat holds the stage cursor this round: the first seat on the picking
## team (DESIGN 2.2 names the team, not the player).
func stage_picker_seat() -> int:
	var team := stage_picker_team()
	for seat in seat_count():
		if team_of_seat(seat) == team:
			return seat
	return 0
#endregion

func coinflip(player_a: int, player_b: int) -> int:
	return player_a if rng.randi() % 2 == 0 else player_b

## Which team picks the stage this round (DESIGN 2.2).
func stage_picker_team() -> int:
	return MatchState.stage_picker(round_index, coinflip_winner_team)
#endregion
