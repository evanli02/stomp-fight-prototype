extends Node
## Audio — every sound the game makes, and the only thing allowed to make one.
##
## Cues are named, not paths: callers say `Audio.play(&"stomp")` and never learn
## where a file lives or how many players are free. That indirection is the whole
## point — retuning the mix, ducking a cue, or swapping a file is a change here
## and nowhere else.
##
## **Audio may never affect gameplay.** It reads state and plays sounds; it never
## writes. Two consequences that are easy to get wrong and are asserted in the
## match harness: an unknown cue is ignored rather than pushed as an error (a
## typo in a cue name must not stop a round), and nothing here runs on the
## physics tick, so a missing or slow stream cannot change a frame's outcome.
##
## Wired to the signals that already exist rather than to call sites, wherever a
## signal exists for the event. A cue that fires off `MatchState.life_lost` keeps
## working when a new way to lose a life appears; a cue sprinkled at call sites
## does not.

## Every cue, and the file behind it. Adding a sound means adding a line here and
## a `save()` in assets/tools/generate_sfx.py — the two are checked against each
## other by the match harness, so one without the other fails a test.
const CUES: Dictionary = {
	&"jump": "res://assets/sfx/jump.wav",
	&"land": "res://assets/sfx/land.wav",
	&"dash": "res://assets/sfx/dash.wav",
	&"perfect": "res://assets/sfx/perfect.wav",
	&"wall_jump": "res://assets/sfx/wall_jump.wav",
	&"pole_grab": "res://assets/sfx/pole_grab.wav",
	&"stomp": "res://assets/sfx/stomp.wav",
	&"bounce": "res://assets/sfx/bounce.wav",
	&"stun": "res://assets/sfx/stun.wav",
	&"life_lost": "res://assets/sfx/life_lost.wav",
	&"hero_out": "res://assets/sfx/hero_out.wav",
	&"swap": "res://assets/sfx/swap.wav",
	&"ability": "res://assets/sfx/ability.wav",
	&"ultimate": "res://assets/sfx/ultimate.wav",
	&"spring": "res://assets/sfx/spring.wav",
	&"portal": "res://assets/sfx/portal.wav",
	&"round_won": "res://assets/sfx/round_won.wav",
	&"match_won": "res://assets/sfx/match_won.wav",
}

## Voices. Six local players in a brawl generate a lot of overlapping cues, and a
## pool this size means a stomp is never cut off by somebody's footstep.
const VOICES: int = 24
## Same cue twice inside this many seconds is one cue. Several elements can
## report the same event on one tick — a body touching two spring tiles, a stomp
## seen by both parties — and without this they phase against each other into a
## flam that sounds like a bug.
const DEDUPE: float = 0.04

var master_volume: float = 1.0

var _streams: Dictionary = {}          ## cue -> AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
## cue -> engine time it last played, for DEDUPE.
var _last_played: Dictionary = {}

func _ready() -> void:
	# Never pauses: the results banner pauses nothing today, but a pause menu
	# later should still be able to click.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for cue in CUES:
		var stream := load(CUES[cue]) as AudioStream
		if stream != null:
			_streams[cue] = stream
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"Master"
		add_child(voice)
		_voices.append(voice)
	_connect_signals()

## Play a cue. `volume_scale` is linear and multiplies the cue's own level;
## `pitch` shifts it, which is how one file covers a family of events.
##
## Unknown cues are ignored on purpose. A misspelled name is a silent sound, not
## a broken round — this is the one subsystem where failing quietly is right.
func play(cue: StringName, volume_scale: float = 1.0, pitch: float = 1.0) -> void:
	if not _streams.has(cue) or master_volume <= 0.0:
		return
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - float(_last_played.get(cue, -999.0)) < DEDUPE:
		return
	_last_played[cue] = now
	var voice := _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = _streams[cue]
	voice.volume_db = linear_to_db(clampf(volume_scale * master_volume, 0.001, 4.0))
	voice.pitch_scale = clampf(pitch, 0.1, 4.0)
	voice.play()

## Register a player's own movement cues. Stages call this for each body they
## seat; the state machine stays unaware that audio exists.
func attach_player(p: Player) -> void:
	if p == null or p.stomp_landed.is_connected(_on_stomp_landed):
		return
	p.stomp_landed.connect(_on_stomp_landed)
	p.stun_applied.connect(_on_stun_applied)
	p.perfect_window_hit.connect(_on_perfect)

func _connect_signals() -> void:
	MatchState.life_lost.connect(_on_life_lost)
	MatchState.hero_eliminated.connect(_on_hero_eliminated)
	MatchState.hero_swapped.connect(_on_hero_swapped)
	MatchState.ultimate_spent.connect(_on_ultimate)
	MatchState.round_won.connect(_on_round_won)
	GameManager.match_won.connect(_on_match_won)

#region Signal handlers
func _on_stomp_landed(_victim: Player) -> void:
	play(&"stomp")

func _on_stun_applied(duration: float) -> void:
	# Longer stuns sound lower, so how long you are stuck is audible before the
	# bar over your head has been read.
	play(&"stun", 0.9, clampf(1.25 - duration * 0.2, 0.6, 1.25))

func _on_perfect(_kind: StringName) -> void:
	play(&"perfect", 0.8)

func _on_life_lost(_player_id: int, _hero_id: StringName, lives_left: int) -> void:
	# The last life of a hero is a different event from the first, and the pitch
	# is what says so before the pips have been looked at.
	play(&"life_lost", 1.0, 1.0 if lives_left > 0 else 0.82)

func _on_hero_eliminated(_player_id: int, _hero_id: StringName) -> void:
	play(&"hero_out")

func _on_hero_swapped(_player_id: int, _from: StringName, _to: StringName) -> void:
	play(&"swap", 0.7)

func _on_ultimate(_player_id: int) -> void:
	play(&"ultimate")

func _on_round_won(_team_id: int) -> void:
	play(&"round_won")

func _on_match_won(_team_id: int) -> void:
	play(&"match_won")
#endregion
