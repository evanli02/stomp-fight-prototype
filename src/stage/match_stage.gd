class_name MatchStage extends Node2D
## Everything a playable stage does that is not its layout: seats, spawns, the
## round loop, respawns, and the debug overlay. Stages subclass this and supply
## geometry, terrain and palette — nothing else.
##
## Division of labour, unchanged from when this was all in duel.gd — GameManager
## owns phases and match-level decisions and holds no scene references;
## MatchState owns the numbers; the stage owns the bodies. Nothing above a stage
## knows a Player node exists, which is what keeps the autoloads testable
## without a tree.
##
## Subclasses override the hooks in the "stage definition" region below. The
## base never reads a subclass field directly, so a stage can compute its layout
## however it likes.

## Long enough for the confetti pop to read before the next hero arrives
## (DESIGN 3.3). Presentation pacing, not a feel number.
const RESPAWN_DELAY: float = 0.6
const EVENT_LOG_LINES: int = 5
## Fallback terrain colour for a stage that ships no ground texture.
const TERRAIN_COLOR: Color = Color(0.16, 0.18, 0.28)

## Seat rosters used only when a stage is booted standalone (F6) with no match
## in progress. Trios picked to be visually distinct from each other.
const SEAT_ROSTERS: Array = [
	[&"deadeye", &"fei", &"terra"],
	[&"cerebelle", &"sai", &"slip"],
]

@onready var players: Array[Player] = [%Player1, %Player2]
@onready var readout: Label = %Readout
@onready var banner: Label = %Banner

var _blocks: Array[Rect2] = []
var _events: Array[String] = []
## player_id -> seconds until their next hero arrives.
var _respawning: Dictionary = {}

func _ready() -> void:
	_blocks = arena_blocks()
	Arena.build(self, _blocks)
	build_terrain()
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
	# no match yet, so start one from the fallback rosters. Arriving from the
	# select screens there already is one, and re-starting it would throw the
	# picks away.
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

#region Stage definition — subclasses override these
## Arena footprint in 16px tiles. Used for the sky and the sealed box.
func arena_size() -> Vector2i:
	return Vector2i(72, 40)

## Where each seat starts the round. One entry per player, opposite sides
## (DESIGN 6.1).
func spawns() -> Array[Vector2]:
	return [Vector2(200, 408), Vector2(952, 408)]

## Every solid rectangle in the stage, including the sealed box.
func arena_blocks() -> Array[Rect2]:
	return Arena.sealed_box(arena_size())

## Instantiate and place the stage's TerrainElements. Called once, after the
## collision blocks exist.
func build_terrain() -> void:
	pass

## Registry key in GameManager.STAGE_ROSTER. The display name and blurb live
## there so the select screen can read them without instantiating a stage;
## returning an empty id (a debug stage that was never registered) is fine and
## just means no name in the overlay.
func stage_id() -> StringName:
	return &""

func stage_name() -> String:
	return GameManager.stage_info(stage_id(), "name", "Unregistered stage")

## Backdrop gradient, top band first, and the y the gradient ends at.
func sky_bands() -> Array[Color]:
	return [Color(0.10, 0.06, 0.19), Color(0.16, 0.11, 0.29)]

func horizon() -> float:
	return float(arena_size().y * Arena.TILE) * 0.6

## Solid fill below the horizon.
func ground_fill() -> Color:
	return Color(0.05, 0.03, 0.09)

## 16px tile for the collision blocks, or null to fill them flat.
func ground_texture() -> Texture2D:
	return null

## Lit cap drawn along the top edge of every block, so a surface reads as
## standable at a glance.
func cap_color() -> Color:
	return Color(0.63, 0.24, 0.47)
#endregion

func _draw() -> void:
	Arena.draw_sky(self, Vector2(arena_size()) * float(Arena.TILE), sky_bands(),
		horizon(), ground_fill())
	var tex := ground_texture()
	if tex != null:
		Arena.draw_tiled(self, _blocks, tex, cap_color())
	else:
		Arena.draw(self, _blocks, TERRAIN_COLOR)

func _spawn_all() -> void:
	var at := spawns()
	for i in players.size():
		players[i].respawn_at(at[i])
		players[i].equip_hero(MatchState.active_hero(i))

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
	players[player_id].respawn_at(spawns()[player_id])
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
		"%s   P1 mouse+keyboard   P2 controller   (swap: RMB / L2, ability: LMB / L1, ult: E / R2+L2)"
			% stage_name(),
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
