extends Node
## GameManager — match lifecycle FSM: LOBBY -> HERO_SELECT -> STAGE_SELECT ->
## ROUND_ACTIVE -> ROUND_RESULTS -> (loop | MATCH_RESULTS).
## Owns the seeded RNG (determinism posture, IMPLEMENTATION.md #9) and the hero roster.

enum Phase { LOBBY, HERO_SELECT, STAGE_SELECT, ROUND_ACTIVE, ROUND_RESULTS, MATCH_RESULTS }

signal phase_changed(phase: Phase)

## Registered heroes: id -> HeroData resource path. Extend via SKILL.md "Add a hero".
const HERO_ROSTER: Dictionary = {
	&"deadeye": "res://src/heroes/resources/deadeye.tres",
	&"skyla": "res://src/heroes/resources/skyla.tres",
	&"mason": "res://src/heroes/resources/mason.tres",
	&"nova": "res://src/heroes/resources/nova.tres",
}

var rng := RandomNumberGenerator.new()
var phase: Phase = Phase.LOBBY

## Lobby config
var team_size: int = 1          # 1, 2, or 3
var best_of: int = 3            # 1, 3, or 5

func _ready() -> void:
	rng.seed = hash("overstomp")  # TODO(M3): seed per match, share for future netcode
	# Every feel number and every harness expectation is written against a 60 Hz
	# gameplay tick (IMPLEMENTATION.md 9). project.godot states it explicitly,
	# but the editor prunes settings that match the engine default on save, so
	# the rule is asserted here where nothing can quietly drop it.
	assert(Engine.physics_ticks_per_second == 60,
		"Overstomp requires a 60 Hz physics tick, got %d" % Engine.physics_ticks_per_second)

func coinflip(player_a: int, player_b: int) -> int:
	return player_a if rng.randi() % 2 == 0 else player_b

func set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)

# TODO(M3): round loop orchestration — hero select timer, stage picker resolution
# via MatchState.stage_picker(), round reset (lives, cooldowns, ultimate restore).
