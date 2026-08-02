extends Node
## MatchState — single source of truth for rosters, lives, eliminations,
## ability cooldowns, ultimate availability, and round wins. Pure data + signals;
## no scene refs, no node lookups, nothing that needs a tree to be true.
##
## Cooldowns live here rather than on the Ability node because they are PER HERO
## and keep ticking while that hero is benched (DESIGN 2.4) — the ability node is
## freed on swap, so it cannot be the one remembering.

signal life_lost(player_id: int, hero_id: StringName, lives_left: int)
signal hero_eliminated(player_id: int, hero_id: StringName)
signal player_eliminated(player_id: int)
signal round_won(team_id: int)
signal ultimate_spent(player_id: int)
signal hero_swapped(player_id: int, from_hero: StringName, to_hero: StringName)
signal cooldown_started(player_id: int, hero_id: StringName, duration: float)

const LIVES_PER_HERO: int = 2
const HEROES_PER_PLAYER: int = 3
## ONE ultimate per HERO per round (DESIGN 2.3), with a gap enforced between any
## two of a player's ultimates. Changed from two-per-player on 2026-08-01: a
## shared pool meant the best ultimate in a trio got used twice and the other
## two were decoration. Per hero, every pick you make is an ultimate you are
## choosing to bring, which is what makes the trio a draft.
##
## The gap survives the change and is still per PLAYER — it exists so a player
## cannot dump their whole round into one scramble, and swapping heroes must not
## be a way around that.
const ULT_COOLDOWN: float = 10.0

## player_id -> {
##   team: int, heroes: { hero_id: lives_remaining }, order: Array[StringName],
##   active: StringName, ults_used: { hero_id: bool }, ult_cooldown: float,
##   cooldowns: { hero_id: seconds }
## }
var players: Dictionary = {}
var round_wins: Dictionary = {}          # team_id -> wins
var last_round_loser_team: int = -1
## Training-room switches, split because the room wants them independent:
## ultimates are ALWAYS free there (no budget, no gap) while ability cooldowns
## are a toggle. Set ONLY by the training room, cleared when it exits — a match
## never turns either on, and `reset_round` deliberately does not touch them
## (they belong to the session, not the round).
var free_cooldowns: bool = false
var free_ultimates: bool = false

func clear_players() -> void:
	## Wipe the roster before a scene registers its own. Round wins survive —
	## they belong to the match, not the round.
	players.clear()

## Is this player part of the current round? Debug scenes (playground) run
## bodies that were never registered, and a stomp there must not crash.
func has_player(player_id: int) -> bool:
	return players.has(player_id)

func register_player(player_id: int, team_id: int, hero_ids: Array[StringName]) -> void:
	## A real round always registers HEROES_PER_PLAYER (hero select enforces it);
	## short rosters are allowed so combat scenes can run a single dummy hero.
	assert(hero_ids.size() > 0 and hero_ids.size() <= HEROES_PER_PLAYER)
	var heroes := {}
	var cooldowns := {}
	var ults_used := {}
	for h in hero_ids:
		heroes[h] = LIVES_PER_HERO
		cooldowns[h] = 0.0
		ults_used[h] = false
	players[player_id] = {
		"team": team_id,
		"heroes": heroes,
		"order": hero_ids.duplicate(),
		"active": hero_ids[0],
		"ults_used": ults_used,
		"ult_cooldown": 0.0,
		"cooldowns": cooldowns,
	}

#region Roster queries
func active_hero(player_id: int) -> StringName:
	return players[player_id].active

func roster(player_id: int) -> Array:
	return players[player_id].order

func lives_of(player_id: int, hero_id: StringName) -> int:
	return players[player_id].heroes.get(hero_id, 0)

func team_of(player_id: int) -> int:
	return players[player_id].team

func living_heroes(player_id: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for h in players[player_id].order:
		if players[player_id].heroes[h] > 0:
			out.append(h)
	return out

func is_out(player_id: int) -> bool:
	return living_heroes(player_id).is_empty()
#endregion

#region Swapping
## Swap has no cooldown and no cost; it only fails when the target cannot be
## swapped to (DESIGN 2.4). Being stunned blocks the swap at the INPUT layer,
## not here — MatchState does not know what a stun is.
func can_swap_to(player_id: int, hero_id: StringName) -> bool:
	var p: Dictionary = players.get(player_id, {})
	if p.is_empty() or hero_id == p.active:
		return false
	return p.heroes.get(hero_id, 0) > 0

func swap_to(player_id: int, hero_id: StringName) -> bool:
	if not can_swap_to(player_id, hero_id):
		return false
	var from: StringName = players[player_id].active
	players[player_id].active = hero_id
	hero_swapped.emit(player_id, from, hero_id)
	return true

## Next living hero after the active one, wrapping. Returns the active hero if
## it is the only one left, so callers can compare and skip a pointless swap.
func next_living_hero(player_id: int) -> StringName:
	var order: Array = players[player_id].order
	var start := order.find(players[player_id].active)
	for step in range(1, order.size() + 1):
		var candidate: StringName = order[(start + step) % order.size()]
		if players[player_id].heroes[candidate] > 0:
			return candidate
	return players[player_id].active
#endregion

#region Cooldowns and ultimates
func start_cooldown(player_id: int, hero_id: StringName, duration: float) -> void:
	players[player_id].cooldowns[hero_id] = duration
	cooldown_started.emit(player_id, hero_id, duration)

func cooldown_remaining(player_id: int, hero_id: StringName) -> float:
	return players[player_id].cooldowns.get(hero_id, 0.0)

func is_ability_ready(player_id: int, hero_id: StringName) -> bool:
	if free_cooldowns:
		return true
	return cooldown_remaining(player_id, hero_id) <= 0.0

## Ticked by GameManager during ROUND_ACTIVE only, so cooldowns do not burn down
## behind a results screen. Every hero ticks, benched included — swapping out is
## never a way to reset an ability (CLAUDE.md checklist).
func tick_cooldowns(delta: float) -> void:
	for pid in players:
		var cds: Dictionary = players[pid].cooldowns
		for hero in cds:
			if cds[hero] > 0.0:
				cds[hero] = maxf(cds[hero] - delta, 0.0)
		if players[pid].ult_cooldown > 0.0:
			players[pid].ult_cooldown = maxf(players[pid].ult_cooldown - delta, 0.0)

## Whether the player's ACTIVE hero can ultimate right now: that hero has not
## spent theirs this round, and the player is not inside the gap.
func ult_available(player_id: int) -> bool:
	if free_ultimates:
		return true
	var p: Dictionary = players[player_id]
	return not ult_spent(player_id, p.active) and p.ult_cooldown <= 0.0

## Has this specific hero used their one ultimate this round (DESIGN 2.3)?
func ult_spent(player_id: int, hero_id: StringName) -> bool:
	if not players.has(player_id):
		return false
	return bool(players[player_id].ults_used.get(hero_id, false))

## How many of the player's heroes still hold an unspent ultimate. Drives the
## HUD's lamp row, which now has one lamp per hero rather than per charge.
func ults_left(player_id: int) -> int:
	if not players.has(player_id):
		return 0
	var count := 0
	for h in players[player_id].ults_used:
		if not players[player_id].ults_used[h]:
			count += 1
	return count

func ult_cooldown_remaining(player_id: int) -> float:
	return players[player_id].ult_cooldown

func try_spend_ultimate(player_id: int) -> bool:
	## One ultimate per HERO per round, with ULT_COOLDOWN between any two of the
	## player's (DESIGN 2.3). Spending one even to no effect consumes it — for
	## that hero, for the rest of the round.
	if not ult_available(player_id):
		return false
	if free_ultimates:
		ultimate_spent.emit(player_id)   # the HUD and audio still want the event
		return true
	# Spent against the ACTIVE hero: it is that hero's one use for the round,
	# and swapping afterwards brings a hero who still has their own.
	players[player_id].ults_used[players[player_id].active] = true
	players[player_id].ult_cooldown = ULT_COOLDOWN
	ultimate_spent.emit(player_id)
	return true
#endregion

#region Combat results
## Put a hero's lives back without resetting the round. The training room calls
## this on its dummies so they can be stomped over and over without the round
## ending; nothing in a real match does.
func restore_lives(player_id: int, hero_id: StringName) -> void:
	if not players.has(player_id):
		return
	players[player_id].heroes[hero_id] = LIVES_PER_HERO

func lose_life(player_id: int, hero_id: StringName) -> void:
	var p: Dictionary = players[player_id]
	if p.heroes.get(hero_id, 0) <= 0:
		return  # already eliminated: there is nothing left to take
	p.heroes[hero_id] -= 1
	life_lost.emit(player_id, hero_id, p.heroes[hero_id])
	if p.heroes[hero_id] <= 0:
		hero_eliminated.emit(player_id, hero_id)
		_check_eliminations(player_id)

func _check_eliminations(player_id: int) -> void:
	if living_heroes(player_id).is_empty():
		player_eliminated.emit(player_id)
	_check_round_win()

func _check_round_win() -> void:
	## A team wins when no other team has any living heroes.
	var alive_teams := {}
	for pid in players:
		if not living_heroes(pid).is_empty():
			alive_teams[players[pid].team] = true
	if alive_teams.size() == 1:
		var winner: int = alive_teams.keys()[0]
		round_wins[winner] = round_wins.get(winner, 0) + 1
		for pid in players:
			if players[pid].team != winner:
				last_round_loser_team = players[pid].team
				break
		round_won.emit(winner)

func wins_for(team_id: int) -> int:
	return round_wins.get(team_id, 0)

func stage_picker(round_index: int, coinflip_winner: int) -> int:
	## Round 1: coinflip winner. Later rounds: the losing team of the previous
	## round. This answers with a TEAM; which of that team's seats holds the
	## cursor is GameManager.stage_picker_seat().
	if round_index == 0:
		return coinflip_winner
	# No loser on record means the previous round never resolved through
	# round_won — a debug jump, or a match restarted mid-round. Fall back rather
	# than hand a caller -1, which would index a seat that does not exist.
	if last_round_loser_team < 0:
		return coinflip_winner
	return last_round_loser_team

func reset_round() -> void:
	## Lives, cooldowns, ultimate, and the active hero all go back to the start.
	## Round wins do not — those are the match.
	for pid in players:
		var p: Dictionary = players[pid]
		for h in p.heroes:
			p.heroes[h] = LIVES_PER_HERO
		# Cooldowns are cleared by THEIR keys, not the roster's: debug scenes can
		# equip off-roster heroes, and a reset that misses those leaves a ghost
		# cooldown ticking into the next round.
		for h in p.cooldowns:
			p.cooldowns[h] = 0.0
		# Same reasoning as the cooldowns above: reset by the dict's own keys so
		# an off-roster hero equipped by a debug scene cannot keep a spent ult.
		for h in p.ults_used:
			p.ults_used[h] = false
		p.ult_cooldown = 0.0
		p.active = p.order[0]
#endregion
