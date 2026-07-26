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
## Ultimates per player per round, and the gap enforced between them
## (DESIGN 2.3). Two makes the ult a resource you can plan around instead of a
## single all-or-nothing moment; the gap stops both going off at once.
const ULTS_PER_ROUND: int = 2
const ULT_COOLDOWN: float = 10.0

## player_id -> {
##   team: int, heroes: { hero_id: lives_remaining }, order: Array[StringName],
##   active: StringName, ults_left: int, ult_cooldown: float,
##   cooldowns: { hero_id: seconds }
## }
var players: Dictionary = {}
var round_wins: Dictionary = {}          # team_id -> wins
var last_round_loser_team: int = -1

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
	for h in hero_ids:
		heroes[h] = LIVES_PER_HERO
		cooldowns[h] = 0.0
	players[player_id] = {
		"team": team_id,
		"heroes": heroes,
		"order": hero_ids.duplicate(),
		"active": hero_ids[0],
		"ults_left": ULTS_PER_ROUND,
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

func ult_available(player_id: int) -> bool:
	var p: Dictionary = players[player_id]
	return p.ults_left > 0 and p.ult_cooldown <= 0.0

func ults_left(player_id: int) -> int:
	return players[player_id].ults_left

func ult_cooldown_remaining(player_id: int) -> float:
	return players[player_id].ult_cooldown

func try_spend_ultimate(player_id: int) -> bool:
	## ULTS_PER_ROUND per player per round, shared across their 3 heroes, with
	## ULT_COOLDOWN between them (DESIGN 2.3). Spending one even to no effect
	## consumes it.
	if not ult_available(player_id):
		return false
	players[player_id].ults_left -= 1
	players[player_id].ult_cooldown = ULT_COOLDOWN
	ultimate_spent.emit(player_id)
	return true
#endregion

#region Combat results
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
	## round — TODO(M6): resolve which player on multi-player teams.
	if round_index == 0:
		return coinflip_winner
	return last_round_loser_team

func reset_round() -> void:
	## Lives, cooldowns, ultimate, and the active hero all go back to the start.
	## Round wins do not — those are the match.
	for pid in players:
		var p: Dictionary = players[pid]
		for h in p.heroes:
			p.heroes[h] = LIVES_PER_HERO
			p.cooldowns[h] = 0.0
		p.ults_left = ULTS_PER_ROUND
		p.ult_cooldown = 0.0
		p.active = p.order[0]
#endregion
