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

var _current: Node = null

func _ready() -> void:
	# The stage is swapped in on round_started rather than on the ROUND_ACTIVE
	# phase change. A stage's _ready spawns the round itself when it finds the
	# signal has already gone out, and arriving one step later is what makes that
	# the branch it takes; listening to the phase instead would put the stage in
	# the tree just early enough to spawn twice.
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.round_started.connect(_on_round_started)
	# Lobby first: it is the only screen that decides how many seats exist, and
	# every screen after it sizes itself from GameManager.team_size.
	_show_lobby()

func _on_phase_changed(phase: GameManager.Phase) -> void:
	if phase == GameManager.Phase.STAGE_SELECT:
		_show_stage_select()
	elif phase == GameManager.Phase.HERO_SELECT:
		_show_hero_select()

## Every round gets a fresh stage instance, because every round can be on a
## different stage. Rebuilding one that did not change costs a frame and keeps
## this branch-free.
func _on_round_started(_index: int) -> void:
	var scene := GameManager.stage_scene(GameManager.current_stage)
	if scene == null:
		push_error("No scene registered for stage '%s'" % GameManager.current_stage)
		return
	_show(scene.instantiate())

func _show_lobby() -> void:
	var screen := LOBBY.instantiate()
	_show(screen)
	screen.lobby_confirmed.connect(_on_lobby_confirmed)

## begin_hero_select flips the phase, and the phase handler is what puts the
## screen up — so the two paths into hero select (here, and a future rematch)
## cannot get out of step.
func _on_lobby_confirmed() -> void:
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
