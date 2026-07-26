extends Node2D
## The 1v1 arena: two seats, three heroes each, a full round loop.
##
## Division of labour — GameManager owns phases and match-level decisions and
## holds no scene references; MatchState owns the numbers; this scene owns the
## bodies. Nothing above it knows a Player node exists, which is what keeps the
## autoloads testable without a tree.

## Rooftop Rumble. Sized Large (DESIGN 6.1: ~72x40) rather than the Small a 1v1
## calls for — this is also the movement test bench, and momentum needs runway:
## a capped run crosses a Small stage in under two seconds, which leaves nothing
## to actually chain b-hops or wall jumps across.
const ARENA: Vector2i = Vector2i(72, 40)
## Opposite rooftops (DESIGN 6.1: team spawns on opposite sides).
const SPAWNS: Array[Vector2] = [Vector2(200, 408), Vector2(952, 408)]
## The rooftop line; sky above it, dark city below.
const HORIZON: float = 432.0
const SKY: Array[Color] = [
	Color(0.10, 0.06, 0.19), Color(0.16, 0.11, 0.29),
	Color(0.23, 0.18, 0.39), Color(0.42, 0.18, 0.36),
]
## Seat rosters. Hero select fills these in from M3's screen; until it exists the
## arena picks trios that are visually distinct from each other.
const SEAT_ROSTERS: Array = [
	[&"deadeye", &"fei", &"mason"],
	[&"cerebelle", &"mason", &"fei"],
]
## Long enough for the confetti pop to read before the next hero arrives
## (DESIGN 3.3). Presentation pacing, not a feel number.
const RESPAWN_DELAY: float = 0.6
const EVENT_LOG_LINES: int = 5

const TERRAIN_COLOR: Color = Color(0.16, 0.18, 0.28)

@onready var players: Array[Player] = [%Player1, %Player2]
@onready var readout: Label = %Readout
@onready var banner: Label = %Banner

var _ground_tex: Texture2D = load("res://assets/stages/tile_ground.png")
var _blocks: Array[Rect2] = []
var _events: Array[String] = []
## player_id -> seconds until their next hero arrives.
var _respawning: Dictionary = {}

func _ready() -> void:
	_blocks = _arena_blocks()
	Arena.build(self, _blocks)
	_build_terrain()
	for i in players.size():
		players[i].player_id = i
		players[i].team_id = i
		players[i].stomp_landed.connect(_on_stomp_landed.bind(i))
		players[i].stun_applied.connect(_on_stun_applied.bind(i))
	MatchState.life_lost.connect(_on_life_lost)
	MatchState.hero_eliminated.connect(_on_hero_eliminated)
	MatchState.hero_swapped.connect(_on_hero_swapped)
	MatchState.round_won.connect(_on_round_won)
	GameManager.round_started.connect(_on_round_started)
	GameManager.match_won.connect(_on_match_won)
	banner.hide()

	# Standalone (F6 straight into this scene, or a harness loading it) there is
	# no match yet, so start one from the fallback rosters. Arriving from hero
	# select there already is one, and re-starting it would throw the picks away.
	if MatchState.players.is_empty():
		var rosters := {}
		var teams := {}
		for i in players.size():
			var ids: Array[StringName] = []
			for h in SEAT_ROSTERS[i]:
				ids.append(h)
			rosters[i] = ids
			teams[i] = i
		GameManager.start_match(rosters, teams)
	else:
		# round_started already fired before this scene existed.
		_spawn_all()
	queue_redraw()

func _spawn_all() -> void:
	for i in players.size():
		players[i].respawn_at(SPAWNS[i])
		players[i].equip_hero(MatchState.active_hero(i))

## Rooftop Rumble: two facing rooftops over a long open street, stepping
## platforms between them, a contested high slab, and a 64px shaft under that
## slab. The shaft is narrow on purpose — bodies are 22px wide, so 64px is close
## enough that two players climbing it meet, which is what makes wall-jump duels
## (DESIGN 3.4) happen deliberately rather than by accident.
##
## The street runs the full width with nothing on it: b-hop chains need a runway
## with no geometry in the arc, and that is most of why the stage is this big.
##
## Rooftops are slabs with air beneath rather than solid buildings: it keeps the
## whole street open, which is what a stomp game needs. There is nowhere to fall
## to — the box is sealed (DESIGN 6.1).
func _arena_blocks() -> Array[Rect2]:
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

## Rooftop Rumble's terrain, exactly the set DESIGN 6.3 calls for: antennas to
## grab, awnings to bounce off, and one wind corridor between the buildings.
##
## Every element is placed clear of the open street, because the street is the
## b-hop runway and putting anything on it would take away the one part of the
## stage that is deliberately empty.
func _build_terrain() -> void:
	# Antennas: a pole on each rooftop. The movement reset button, parked exactly
	# where a player who has just been chased across the map wants one.
	for x in [160.0, 992.0]:
		var pole := Pole.new()
		pole.size = Vector2(8, 120)
		pole.position = Vector2(x, 372)
		add_child(pole)

	# Awnings: springs on the low ledges, narrow enough to be aimed at rather
	# than fallen onto.
	for x in [224.0, 928.0]:
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

func _draw() -> void:
	# Horizon sits on the rooftop line: sky above, dark city below.
	Arena.draw_sky(self, Vector2(ARENA) * float(Arena.TILE), SKY, HORIZON)
	if _ground_tex != null:
		Arena.draw_tiled(self, _blocks, _ground_tex)
	else:
		Arena.draw(self, _blocks, TERRAIN_COLOR)

func _physics_process(delta: float) -> void:
	for pid in _respawning.keys():
		_respawning[pid] -= delta
		if _respawning[pid] <= 0.0:
			_respawning.erase(pid)
			_bring_in_next_hero(pid)

func _process(_delta: float) -> void:
	readout.text = _debug_text()  # overlay only, no gameplay logic here

#region Round flow
func _on_round_started(index: int) -> void:
	_respawning.clear()
	banner.hide()
	_spawn_all()
	_log("round %d — fight" % [index + 1])

func _on_life_lost(player_id: int, hero_id: StringName, lives_left: int) -> void:
	_log("P%d %s stomped — %d left" % [player_id + 1, hero_id, lives_left])

## A hero out of lives pops and the player's next hero comes in at their spawn
## with brief protection (DESIGN 3.3). If that was the last one, the round is
## already decided and MatchState.round_won is on its way.
func _on_hero_eliminated(player_id: int, hero_id: StringName) -> void:
	players[player_id].play_elimination()
	_log("P%d's %s is out" % [player_id + 1, hero_id])
	if not MatchState.is_out(player_id):
		_respawning[player_id] = RESPAWN_DELAY

func _bring_in_next_hero(player_id: int) -> void:
	var next := MatchState.next_living_hero(player_id)
	MatchState.swap_to(player_id, next)
	players[player_id].respawn_at(SPAWNS[player_id])
	players[player_id].equip_hero(next)

func _on_hero_swapped(player_id: int, _from: StringName, to_hero: StringName) -> void:
	_log("P%d -> %s" % [player_id + 1, to_hero])

func _on_round_won(team_id: int) -> void:
	banner.text = "P%d TAKES THE ROUND  (%d-%d)" % [
		team_id + 1, MatchState.wins_for(0), MatchState.wins_for(1)]
	banner.show()
	GameManager.end_round()

func _on_match_won(team_id: int) -> void:
	banner.text = "P%d WINS THE MATCH" % [team_id + 1]
	banner.show()

func _on_stomp_landed(_victim: Player, attacker_index: int) -> void:
	_log("P%d landed a stomp" % [attacker_index + 1])

func _on_stun_applied(duration: float, player_index: int) -> void:
	_log("P%d stunned %.2fs" % [player_index + 1, duration])
#endregion

#region Debug overlay
func _debug_text() -> String:
	var lines: Array[String] = [
		"P1 mouse+keyboard   P2 controller   (swap: RMB / L2, ability: LMB / L1, ult: E / R2+L2)",
		"",
	]
	for i in players.size():
		lines.append(_player_line(i))
	lines.append("")
	lines.append_array(_events)
	return "\n".join(lines)

func _player_line(index: int) -> String:
	var p := players[index]
	var flags := ""
	if p.stun_remaining > 0.0:
		flags += "  STUN %.2f" % p.stun_remaining
	if p.grace_remaining > 0.0:
		flags += "  %s %.2f" % ["SPAWN" if p.spawn_protected else "GRACE", p.grace_remaining]
	if _respawning.has(index):
		flags += "  RESPAWN %.2f" % _respawning[index]
	var lives := "-"
	if MatchState.has_player(index):
		var parts: Array[String] = []
		for h in MatchState.roster(index):
			parts.append("%s%d" % ["*" if h == MatchState.active_hero(index) else " ",
				MatchState.lives_of(index, h)])
		lives = "".join(parts)
	return "P%d %s  %-10s v(%5.0f,%5.0f)%s" % [
		index + 1, lives, p.state_machine.state_name(), p.velocity.x, p.velocity.y, flags]

func _log(line: String) -> void:
	_events.append(line)
	while _events.size() > EVENT_LOG_LINES:
		_events.pop_front()
#endregion
