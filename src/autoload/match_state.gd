extends Node
## MatchState — single source of truth for rosters, lives, eliminations,
## ultimate availability, and round wins. Pure data + signals; no scene refs.
## Fully covered by GUT tests (tests/test_match_state.gd).

signal life_lost(player_id: int, hero_id: StringName, lives_left: int)
signal hero_eliminated(player_id: int, hero_id: StringName)
signal player_eliminated(player_id: int)
signal round_won(team_id: int)
signal ultimate_spent(player_id: int)

const LIVES_PER_HERO: int = 2
const HEROES_PER_PLAYER: int = 3

## player_id -> { team: int, heroes: { hero_id: lives_remaining }, ult_available: bool }
var players: Dictionary = {}
var round_wins: Dictionary = {}          # team_id -> wins
var last_round_loser_team: int = -1

func register_player(player_id: int, team_id: int, hero_ids: Array[StringName]) -> void:
	assert(hero_ids.size() == HEROES_PER_PLAYER)
	var heroes := {}
	for h in hero_ids:
		heroes[h] = LIVES_PER_HERO
	players[player_id] = { "team": team_id, "heroes": heroes, "ult_available": true }

func lose_life(player_id: int, hero_id: StringName) -> void:
	var p: Dictionary = players[player_id]
	p.heroes[hero_id] -= 1
	life_lost.emit(player_id, hero_id, p.heroes[hero_id])
	if p.heroes[hero_id] <= 0:
		hero_eliminated.emit(player_id, hero_id)
		_check_eliminations(player_id)

func try_spend_ultimate(player_id: int) -> bool:
	## One ultimate per player per round, shared across their 3 heroes (DESIGN 2.3).
	if not players[player_id].ult_available:
		return false
	players[player_id].ult_available = false
	ultimate_spent.emit(player_id)
	return true

func living_heroes(player_id: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for h in players[player_id].heroes:
		if players[player_id].heroes[h] > 0:
			out.append(h)
	return out

func stage_picker(round_index: int, coinflip_winner: int) -> int:
	## Round 1: coinflip winner. Later rounds: the losing team of the previous
	## round — TODO(M3): resolve which player on multi-player teams.
	if round_index == 0:
		return coinflip_winner
	return last_round_loser_team

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

func reset_round() -> void:
	for pid in players:
		for h in players[pid].heroes:
			players[pid].heroes[h] = LIVES_PER_HERO
		players[pid].ult_available = true
