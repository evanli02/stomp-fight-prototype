extends Node
## Net — online play, host-authoritative (IMPLEMENTATION.md 9a).
##
## The model is deliberately the same one local multiplayer already uses: ONE
## machine simulates everything. Locally that machine reads six devices; online,
## some of those "devices" are remote — a client sends its InputFrame every tick
## and the host treats that seat exactly like a plugged-in pad. All remote input
## enters through the one seam the codebase has always promised for this:
## `InputConfig.poll()` returns the latest received frame for a NET seat, and
## nothing downstream can tell the difference.
##
## Clients are thin. They do not simulate: they receive a per-tick snapshot of
## every body (position, velocity, facing, animation) and a mirror of the
## MatchState numbers the HUD reads, and they re-emit MatchState's signals so
## the HUD, the event log, the stomp pop and the audio all react on the client
## exactly as they do on the host — the mirror speaks the same signal language
## as the real thing.
##
## What this deliberately is NOT (v1): no prediction — a client feels its own
## inputs one round trip late, like a streamed session but far cheaper; no
## select screens over the wire — an online match uses fallback trios and the
## host's stage; desktop-to-desktop ENet only — a browser build cannot host or
## dial a raw socket, and WebRTC needs a signaling service (docs/ITCH.md).
## Rollback stays possible later precisely because everything already flows
## through InputFrame; this layer does not foreclose it.

## Emitted on a client when the host has started a round and the mirror is
## registered: the shell responds by instantiating the stage as a puppet scene.
signal client_round_started(stage_id: StringName, round_index: int)
## Emitted on either side when the session ends (peer lost, or leave() called).
signal session_ended(reason: String)
## Lobby-facing: connection census changed (client joined/left, seat claimed).
signal roster_changed()

enum Mode { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT: int = 30567
const MAX_CLIENTS: int = 5      ## host plays too: 6 seats = 3v3

var mode: Mode = Mode.OFFLINE
## Client only: the seat the host assigned us. -1 until seat_assigned arrives.
var my_seat: int = -1

## Host: peer id -> seat. The census the lobby shows and the input router keys.
var _peer_seats: Dictionary = {}
## Host: seat -> latest InputFrame received. Edges are latched: consumed on
## first read each tick so one remote press cannot fire on two host ticks.
var _remote_frames: Dictionary = {}
## Client: last mirrored active hero per seat, to detect swaps.
var _mirror_active: Dictionary = {}

func _ready() -> void:
	# Signals exist even before hosting; connecting once here keeps host-side
	# broadcast wiring in one place. All handlers no-op while OFFLINE.
	GameManager.round_started.connect(_on_host_round_started)
	GameManager.match_won.connect(func(team: int) -> void:
		if mode == Mode.HOST:
			_ev_match_won.rpc(team))
	MatchState.life_lost.connect(func(pid: int, hero: StringName, left: int) -> void:
		if mode == Mode.HOST:
			_ev_life_lost.rpc(pid, hero, left))
	MatchState.hero_eliminated.connect(func(pid: int, hero: StringName) -> void:
		if mode == Mode.HOST:
			_ev_hero_eliminated.rpc(pid, hero))
	MatchState.round_won.connect(func(team: int) -> void:
		if mode == Mode.HOST:
			_ev_round_won.rpc(team, MatchState.round_wins.duplicate()))

#region Lifecycle
func is_online() -> bool: return mode != Mode.OFFLINE
func is_host() -> bool: return mode == Mode.HOST
func is_client() -> bool: return mode == Mode.CLIENT

func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.HOST
	roster_changed.emit()
	return OK

func join(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(func() -> void: leave("connection failed"))
	multiplayer.server_disconnected.connect(func() -> void: leave("host left"))
	mode = Mode.CLIENT
	return OK

## Tear the session down on either side. Safe to call twice.
func leave(reason: String = "left") -> void:
	if mode == Mode.OFFLINE:
		return
	mode = Mode.OFFLINE
	my_seat = -1
	for seat in _peer_seats.values():
		InputConfig.release_seat(seat)
	_peer_seats.clear()
	_remote_frames.clear()
	_mirror_active.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	session_ended.emit(reason)

func client_count() -> int:
	return _peer_seats.size()
#endregion

#region Connection handling
func _on_peer_connected(_id: int) -> void:
	# The seat is claimed when the client asks, not on raw connect: the claim is
	# the same "a device pressed a button" contract the local lobby uses.
	roster_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	if _peer_seats.has(id):
		var seat: int = _peer_seats[id]
		InputConfig.release_seat(seat)
		_remote_frames.erase(seat)
		_peer_seats.erase(id)
	roster_changed.emit()

func _on_connected_to_host() -> void:
	_request_seat.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request_seat() -> void:
	if mode != Mode.HOST:
		return
	var peer := multiplayer.get_remote_sender_id()
	if _peer_seats.has(peer):
		return
	var seat := InputConfig.claim_remote_seat()
	if seat < 0:
		_seat_assigned.rpc_id(peer, -1)   # lobby full
		return
	_peer_seats[peer] = seat
	_remote_frames[seat] = InputFrame.new()
	_seat_assigned.rpc_id(peer, seat)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _seat_assigned(seat: int) -> void:
	my_seat = seat
	if seat < 0:
		leave("lobby full")
		return
	roster_changed.emit()
#endregion

#region Input relay (client -> host)
## The host reads a NET seat's intent through here — called by InputConfig.poll,
## which is the whole point: menus and bodies alike see an ordinary InputFrame.
func frame_for_seat(seat: int) -> InputFrame:
	var stored: InputFrame = _remote_frames.get(seat)
	if stored == null:
		return InputFrame.new()
	var out := InputFrame.new()
	out.move = stored.move
	out.aim = stored.aim
	out.jump_held = stored.jump_held
	out.jump_pressed = stored.jump_pressed
	out.dash_pressed = stored.dash_pressed
	out.ability_pressed = stored.ability_pressed
	out.swap_pressed = stored.swap_pressed
	out.ultimate_pressed = stored.ultimate_pressed
	# Latch: an edge is spent the tick it is read. The client ticks at its own
	# rate, and without this a single remote press could buffer two jumps.
	stored.jump_pressed = false
	stored.dash_pressed = false
	stored.ability_pressed = false
	stored.swap_pressed = false
	stored.ultimate_pressed = false
	return out

func _physics_process(_delta: float) -> void:
	if mode == Mode.CLIENT and my_seat >= 0:
		_send_local_input()
	elif mode == Mode.HOST:
		_broadcast_snapshot()

## The client polls its own seat-0 devices (its keyboard/mouse/pad) and ships
## the frame. Aim needs the puppet's position for mouse aim, so find our body.
func _send_local_input() -> void:
	var body := _body_for(my_seat)
	var f := InputConfig.poll(0, body)
	# Reliable: a dropped packet holding a press edge would eat a jump, and at
	# 60Hz these packets are tiny. Snapshots take the unreliable channel.
	_receive_input.rpc_id(1, [f.move.x, f.move.y, f.aim.x, f.aim.y,
		int(f.jump_pressed) | int(f.jump_held) << 1 | int(f.dash_pressed) << 2
		| int(f.ability_pressed) << 3 | int(f.swap_pressed) << 4
		| int(f.ultimate_pressed) << 5])

@rpc("any_peer", "call_remote", "reliable")
func _receive_input(data: Array) -> void:
	if mode != Mode.HOST:
		return
	var seat: int = _peer_seats.get(multiplayer.get_remote_sender_id(), -1)
	if seat < 0:
		return
	var stored: InputFrame = _remote_frames.get(seat)
	if stored == null:
		stored = InputFrame.new()
		_remote_frames[seat] = stored
	stored.move = Vector2(data[0], data[1])
	stored.aim = Vector2(data[2], data[3])
	var bits: int = data[4]
	# Edges OR in rather than overwrite: a press must survive until the host
	# tick that consumes it, even if a later frame without the edge lands first.
	stored.jump_pressed = stored.jump_pressed or bool(bits & 1)
	stored.jump_held = bool(bits & 2)
	stored.dash_pressed = stored.dash_pressed or bool(bits & 4)
	stored.ability_pressed = stored.ability_pressed or bool(bits & 8)
	stored.swap_pressed = stored.swap_pressed or bool(bits & 16)
	stored.ultimate_pressed = stored.ultimate_pressed or bool(bits & 32)
#endregion

#region Match flow (host -> clients)
func _on_host_round_started(index: int) -> void:
	if mode != Mode.HOST:
		return
	var rosters := {}
	var teams := {}
	for pid in MatchState.players:
		rosters[pid] = Array(MatchState.roster(pid)).duplicate()
		teams[pid] = MatchState.team_of(pid)
	_ev_round_started.rpc(String(GameManager.current_stage), index, rosters, teams)

@rpc("authority", "call_remote", "reliable")
func _ev_round_started(stage_id: String, index: int, rosters: Dictionary,
		teams: Dictionary) -> void:
	# Build the local mirror the stage and HUD will read. Registering through
	# the real API keeps every derived field (cooldowns, ults) shaped right.
	MatchState.clear_players()
	for pid in rosters:
		var ids: Array[StringName] = []
		for h in rosters[pid]:
			ids.append(StringName(h))
		MatchState.register_player(pid, teams[pid], ids)
		_mirror_active[pid] = MatchState.active_hero(pid)
	GameManager.current_stage = StringName(stage_id)
	GameManager.team_size = maxi(rosters.size() / 2, 1)
	client_round_started.emit(StringName(stage_id), index)

@rpc("authority", "call_remote", "reliable")
func _ev_life_lost(pid: int, hero: StringName, left: int) -> void:
	if MatchState.has_player(pid):
		MatchState.players[pid].heroes[hero] = left
		MatchState.life_lost.emit(pid, hero, left)

@rpc("authority", "call_remote", "reliable")
func _ev_hero_eliminated(pid: int, hero: StringName) -> void:
	if MatchState.has_player(pid):
		MatchState.hero_eliminated.emit(pid, hero)

@rpc("authority", "call_remote", "reliable")
func _ev_round_won(team: int, wins: Dictionary) -> void:
	MatchState.round_wins = wins
	# The stage banner and log react; MatchStage guards GameManager.end_round
	# behind is_client(), so the client never runs its own results countdown —
	# the next _ev_round_started is what advances it.
	MatchState.round_won.emit(team)

@rpc("authority", "call_remote", "reliable")
func _ev_match_won(team: int) -> void:
	GameManager.match_won.emit(team)
#endregion

#region Snapshots (host -> clients, unreliable)
func _broadcast_snapshot() -> void:
	if _peer_seats.is_empty():
		return
	var bodies := get_tree().get_nodes_in_group(&"players")
	if bodies.is_empty():
		return
	var players_data: Array = []
	for node in bodies:
		var p := node as Player
		if p == null:
			continue
		players_data.append([p.player_id, p.global_position.x, p.global_position.y,
			p.velocity.x, p.velocity.y, p.facing,
			String(p.state_machine.current_animation()), p.grace_remaining,
			p.stun_remaining])
	var mirror: Array = []
	for pid in MatchState.players:
		var pd: Dictionary = MatchState.players[pid]
		mirror.append([pid, String(pd.active), pd.cooldowns.duplicate(),
			pd.ults_used.duplicate(), pd.ult_cooldown])
	_snapshot.rpc(players_data, mirror)

@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(players_data: Array, mirror: Array) -> void:
	for entry in players_data:
		var body := _body_for(entry[0])
		if body != null:
			body.apply_net_snapshot(Vector2(entry[1], entry[2]),
				Vector2(entry[3], entry[4]), entry[5], StringName(entry[6]),
				entry[7], entry[8])
	for m in mirror:
		var pid: int = m[0]
		if not MatchState.has_player(pid):
			continue
		var pd: Dictionary = MatchState.players[pid]
		var active := StringName(m[1])
		pd.cooldowns = m[2]
		pd.ults_used = m[3]
		pd.ult_cooldown = m[4]
		if pd.active != active:
			var from: StringName = pd.active
			pd.active = active
			MatchState.hero_swapped.emit(pid, from, active)
			var body := _body_for(pid)
			if body != null:
				body.equip_hero(active)

func _body_for(pid: int) -> Player:
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		if p != null and p.player_id == pid:
			return p
	return null
#endregion
