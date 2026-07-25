extends GutTest
## GUT tests for MatchState (IMPLEMENTATION.md 10). Run via the GUT panel.
## TODO(M3): flesh out. The cases below define the required coverage.

func test_player_starts_with_three_heroes_two_lives_each() -> void:
	pending("M3")

func test_second_life_loss_eliminates_hero() -> void:
	pending("M3")

func test_round_won_when_all_enemy_heroes_eliminated() -> void:
	pending("M3")

func test_ultimate_spendable_exactly_once_per_round() -> void:
	pending("M3")

func test_ultimate_restored_on_round_reset() -> void:
	pending("M3")

func test_stage_picker_round1_is_coinflip_winner_then_previous_loser() -> void:
	pending("M3")

func test_stun_refresh_is_max_not_additive() -> void:
	pending("M3")  # lives on Player; test via headless scene or extract to helper
