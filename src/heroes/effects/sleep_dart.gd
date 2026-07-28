class_name SleepDart extends BoltProjectile
## Vesper's dart: the same flight as Deadeye's bolt (BoltProjectile), carrying a
## short slow and one sleep STACK instead of a stun.
##
## The stack bookkeeping lives on the victim, not here and not on the ability —
## a dart from a benched-then-returned Vesper, or from two Vespers in a
## duplicate-pick lobby, has to land in the same pool. This node only reports
## the new count and decides, from the ability's numbers it was handed, whether
## that count is the one that puts them under.

var slow_mult: float = 0.6
var impair_mult: float = 0.65
var slow_time: float = 2.0
var stack_life: float = 13.0
var stacks_to_sleep: int = 3
var sleep_time: float = 6.5

func _on_hit(victim: Player) -> void:
	victim.apply_slow(slow_mult, slow_time, &"dart")
	victim.apply_impairment(impair_mult, slow_time, &"dart")
	if victim.add_sleep_stack(stack_life) >= stacks_to_sleep:
		# The third dart spends the whole set rather than adding to it.
		victim.consume_sleep_stacks()
		victim.apply_sleep(sleep_time)

func _draw() -> void:
	# A needle, not a bolt: dark shaft, bright tip, small fletching.
	draw_rect(Rect2(-LENGTH * 0.5, -THICKNESS * 0.35, LENGTH, THICKNESS * 0.7),
		Color(0.06, 0.06, 0.09))
	draw_rect(Rect2(LENGTH * 0.5 - 3.0, -THICKNESS * 0.5, 3.0, THICKNESS), accent)
	draw_line(Vector2(-LENGTH * 0.5, -2.0), Vector2(-LENGTH * 0.5 + 3.0, 0.0), accent, 1.0)
	draw_line(Vector2(-LENGTH * 0.5, 2.0), Vector2(-LENGTH * 0.5 + 3.0, 0.0), accent, 1.0)
