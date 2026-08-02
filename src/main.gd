extends Node
## Shell: owns which phase is on screen and nothing else.
##
## GameManager decides what phase the match is in but holds no scene references,
## so something has to translate "we are in STAGE_SELECT now" into nodes. That is
## this file, and keeping it this thin is what lets every other piece be tested
## headlessly without a shell at all — stages and the harnesses instantiate their
## own scenes and never go through here.

const LOBBY := preload("res://src/ui/lobby.tscn")
const HERO_SELECT := preload("res://src/ui/hero_select.tscn")
const STAGE_SELECT := preload("res://src/ui/stage_select.tscn")
const PAUSE_MENU := preload("res://src/ui/pause_menu.tscn")
## Development destinations, reachable from the lobby. Neither is part of the
## match flow — the balance sheet returns to the lobby, and the training room
## runs its own match that no phase change ever advances.
const BALANCE_SHEET := preload("res://src/ui/balance_sheet.tscn")
const TRAINING_ROOM := preload("res://src/stage/training_room.tscn")

var _current: Node = null

func _ready() -> void:
	# The stage is swapped in on round_started rather than on the ROUND_ACTIVE
	# phase change. A stage's _ready spawns the round itself when it finds the
	# signal has already gone out, and arriving one step later is what makes that
	# the branch it takes; listening to the phase instead would put the stage in
	# the tree just early enough to spawn twice.
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.round_started.connect(_on_round_started)
	# Added once and never swapped out: the pause menu outlives every screen and
	# must not be the thing _show() frees. It runs while the tree is paused, so
	# it can undo the pause it caused.
	add_child(PAUSE_MENU.instantiate())
	# Online-client flow: the host's round events are what advance the shell —
	# GameManager's phases never change on a client (IMPLEMENTATION.md 9a).
	Net.client_round_started.connect(_on_client_round_started)
	Net.session_ended.connect(_on_session_ended)
	# Lobby first: it is the only screen that decides how many seats exist, and
	# every screen after it sizes itself from GameManager.team_size.
	_show_lobby()

func _on_phase_changed(phase: GameManager.Phase) -> void:
	if phase == GameManager.Phase.STAGE_SELECT:
		_show_stage_select()
	elif phase == GameManager.Phase.HERO_SELECT:
		_show_hero_select()
	elif phase == GameManager.Phase.LOBBY:
		_show_lobby()

## Every round gets a fresh stage instance, because every round can be on a
## different stage. Rebuilding one that did not change costs a frame and keeps
## this branch-free.
func _on_round_started(_index: int) -> void:
	var scene := GameManager.stage_scene(GameManager.current_stage)
	if scene == null:
		push_error("No scene registered for stage '%s'" % GameManager.current_stage)
		return
	_show(scene.instantiate())

## The host already set current_stage before the event went out, so the host
## path's scene lookup is reused verbatim.
func _on_client_round_started(_stage_id: StringName, index: int) -> void:
	_on_round_started(index)

func _on_session_ended(_reason: String) -> void:
	MatchState.clear_players()
	_show_lobby()

func _show_lobby() -> void:
	var screen := LOBBY.instantiate()
	_show(screen)
	screen.lobby_confirmed.connect(_on_lobby_confirmed)
	screen.balance_sheet_requested.connect(_show_balance_sheet)
	screen.training_room_requested.connect(_show_training_room)

func _show_balance_sheet() -> void:
	var screen := BALANCE_SHEET.instantiate()
	_show(screen)
	screen.closed.connect(_show_lobby)

## The training room starts its own match from its own rosters (MatchStage does
## that whenever it finds no players registered), so this only has to put the
## scene up. Leaving it is the pause menu's quit-to-lobby, like any stage.
func _show_training_room() -> void:
	MatchState.clear_players()
	_show(TRAINING_ROOM.instantiate())

## begin_hero_select flips the phase, and the phase handler is what puts the
## screen up — so the two paths into hero select (here, and a future rematch)
## cannot get out of step.
func _on_lobby_confirmed() -> void:
	# An online match skips the select screens for now: fallback trios, the
	# host's current stage, no stage select between rounds. Select screens over
	# the wire are the documented follow-up (docs/ITCH.md).
	if Net.is_host() and Net.client_count() > 0:
		GameManager.start_quick_match()
		return
	GameManager.begin_hero_select()

func _show_hero_select() -> void:
	var screen := HERO_SELECT.instantiate()
	_show(screen)
	screen.picks_confirmed.connect(_on_picks_confirmed)

func _show_stage_select() -> void:
	var screen := STAGE_SELECT.instantiate()
	_show(screen)
	screen.stage_confirmed.connect(GameManager.choose_stage)

func _on_picks_confirmed(rosters: Dictionary, teams: Dictionary) -> void:
	GameManager.start_match(rosters, teams, true)

func _show(scene: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = scene
	add_child(scene)
