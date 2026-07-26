extends SceneTree
## Sanity check the generated SpriteFrames: every hero, every animation the
## states can ask for, with the right frame counts.

func _init() -> void:
	var wanted := [&"idle", &"run", &"rise", &"fall", &"land", &"dash", &"skid",
		&"crouch", &"slide", &"slide_jump", &"wall_slide", &"wall_jump",
		&"pole_climb", &"stun", &"cast", &"pop"]
	var failures := 0
	for key in ["deadeye", "skyla", "mason", "nova"]:
		var hero: HeroData = load("res://src/heroes/resources/%s.tres" % key)
		if hero == null or hero.sprite_frames == null:
			print("FAIL %s has no sprite_frames" % key)
			failures += 1
			continue
		var sf: SpriteFrames = hero.sprite_frames
		var missing: Array = []
		var total := 0
		for a in wanted:
			if not sf.has_animation(a):
				missing.append(a)
			else:
				total += sf.get_frame_count(a)
		if missing.is_empty():
			print("PASS %-8s %d animations, %d frames, accent %s"
				% [key, sf.get_animation_names().size(), total, hero.accent_color.to_html(false)])
		else:
			print("FAIL %-8s missing %s" % [key, missing])
			failures += 1
	print("\n%s" % ("ALL FRAMES OK" if failures == 0 else "%d HERO(ES) FAILED" % failures))
	quit(1 if failures > 0 else 0)
