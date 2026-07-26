extends Node2D
## M2 exit-criteria scene: a playable 1v1 on one dummy hero. Two seats (KBM and
## pad, per InputConfig), full stomp loop, wall-jump duels, and a readout of the
## things that are invisible on screen — lives, stun, grace, and the last combat
## events.
##
## Round flow here is deliberately minimal: reset when a team wins, nothing else.
## TODO(M3): GameManager owns registration, hero select, the round loop, and the
## respawn/auto-swap that a real 3-hero roster needs (DESIGN 3.3).

const ARENA: Vector2i = Vector2i(50, 22)
const DUMMY_HERO: StringName = &"dummy"
const SPAWNS: Array[Vector2] = [Vector2(120, 220), Vector2(680, 220)]
const TEAM_TINT: Array[Color] = [Color(0.55, 0.85, 1.0), Color(1.0, 0.65, 0.4)]
const RESET_DELAY: float = 2.5
const EVENT_LOG_LINES: int = 5

const TERRAIN_COLOR: Color = Color(0.16, 0.18, 0.28)

@onready var players: Array[Player] = [%Player1, %Player2]
@onready var readout: Label = %Readout
@onready var banner: Label = %Banner

var _blocks: Array[Rect2] = []
var _events: Array[String] = []
var _reset_remaining: float = 0.0

func _ready() -> void:
	_blocks = _arena_blocks()
	Arena.build(self, _blocks)
	MatchState.clear_players()
	for i in players.size():
		var p := players[i]
		p.player_id = i
		p.team_id = i
		p.active_hero = DUMMY_HERO
		p.sprite.modulate = TEAM_TINT[i]
		MatchState.register_player(i, i, [DUMMY_HERO] as Array[StringName])
		p.stomp_landed.connect(_on_stomp_landed.bind(i))
		p.stun_applied.connect(_on_stun_applied.bind(i))
	MatchState.life_lost.connect(_on_life_lost)
	MatchState.round_won.connect(_on_round_won)
	banner.hide()
	queue_redraw()

## Symmetric sealed box (DESIGN 6.1): mirrored spawn ledges to open from, a high
## centre platform worth contesting, and a pillar shaft where two players meet
## in the air often enough to make wall-jump duels happen on purpose.
func _arena_blocks() -> Array[Rect2]:
	var t := float(Arena.TILE)
	var blocks := Arena.sealed_box(ARENA)
	blocks.append_array([
		Rect2(96.0, 256.0, 128.0, t),
		Rect2(576.0, 256.0, 128.0, t),
		Rect2(352.0, 160.0, 96.0, t),
		Rect2(288.0, 208.0, t, 128.0),
		Rect2(496.0, 208.0, t, 128.0),
	])
	return blocks

func _draw() -> void:
	Arena.draw(self, _blocks, TERRAIN_COLOR)

func _physics_process(delta: float) -> void:
	if _reset_remaining <= 0.0:
		return
	_reset_remaining -= delta
	if _reset_remaining <= 0.0:
		_reset_round()

func _process(_delta: float) -> void:
	readout.text = _debug_text()  # overlay only, no gameplay logic here

#region Round flow (M2 placeholder — GameManager takes this over in M3)
func _on_life_lost(player_id: int, _hero_id: StringName, lives_left: int) -> void:
	_log("P%d stomped — %d live(s) left" % [player_id + 1, lives_left])

func _on_round_won(team_id: int) -> void:
	banner.text = "P%d WINS THE ROUND" % (team_id + 1)
	banner.show()
	_reset_remaining = RESET_DELAY

func _reset_round() -> void:
	MatchState.reset_round()
	for i in players.size():
		players[i].respawn_at(SPAWNS[i])
	banner.hide()
	_log("round reset")

func _on_stomp_landed(_victim: Player, attacker_index: int) -> void:
	_log("P%d landed a stomp" % [attacker_index + 1])

func _on_stun_applied(duration: float, player_index: int) -> void:
	_log("P%d stunned %.2fs" % [player_index + 1, duration])
#endregion

#region Debug overlay
func _debug_text() -> String:
	var lines: Array[String] = ["P1: mouse+keyboard    P2: controller", ""]
	for i in players.size():
		lines.append(_player_line(i))
	lines.append("")
	lines.append_array(_events)
	return "\n".join(lines)

func _player_line(index: int) -> String:
	var p := players[index]
	var lives: int = MatchState.players[index]["heroes"][DUMMY_HERO] \
		if MatchState.has_player(index) else 0
	var flags := ""
	if p.stun_remaining > 0.0:
		flags += "  STUN %.2f" % p.stun_remaining
	if p.grace_remaining > 0.0:
		flags += "  %s %.2f" % ["SPAWN" if p.spawn_protected else "GRACE", p.grace_remaining]
	return "P%d  lives %d  %-10s v(%5.0f,%5.0f)%s" % [
		index + 1, lives, p.state_machine.state_name(), p.velocity.x, p.velocity.y, flags]

func _log(line: String) -> void:
	_events.append(line)
	while _events.size() > EVENT_LOG_LINES:
		_events.pop_front()
#endregion
