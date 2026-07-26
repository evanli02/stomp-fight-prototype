extends Node
## Shell: owns which phase is on screen and nothing else.
##
## GameManager decides what phase the match is in but holds no scene references,
## so something has to translate "we are in HERO_SELECT now" into nodes. That is
## this file, and keeping it this thin is what lets every other piece be tested
## headlessly without a shell at all — the arena and the harnesses instantiate
## their own scenes and never go through here.

const HERO_SELECT := preload("res://src/ui/hero_select.tscn")
const ARENA := preload("res://src/stage/duel.tscn")

var _current: Node = null

func _ready() -> void:
	GameManager.begin_hero_select()
	_show(HERO_SELECT.instantiate())
	_current.picks_confirmed.connect(_on_picks_confirmed)

func _on_picks_confirmed(rosters: Dictionary, teams: Dictionary) -> void:
	GameManager.start_match(rosters, teams)
	_show(ARENA.instantiate())

func _show(scene: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = scene
	add_child(scene)
