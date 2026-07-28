extends Node
## Dev-only: boot the two select screens, screenshot each, and quit. Run
## windowed (rendering must exist for there to be pixels):
##   Godot --path . res://tools/screenshot_select.tscn
## Writes PNGs next to the project in screenshots/.

const OUT_DIR := "res://screenshots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	GameManager.team_size = 1

	var hero_select: CanvasLayer = load("res://src/ui/hero_select.tscn").instantiate()
	add_child(hero_select)
	await _settle()
	# A half-made state, so the shot shows picks, cursors, and the waiting line.
	hero_select._pick(0, &"deadeye")
	hero_select._pick(0, &"voodoo")
	hero_select._cursor[0] = 8
	hero_select._cursor[1] = 8   # two cursors on one tile, to see the nesting
	await _settle()
	await _shoot("hero_select.png")
	hero_select.queue_free()

	# The worst-case format: six boxes, six cursors, six kit lines.
	GameManager.team_size = 3
	var crowded: CanvasLayer = load("res://src/ui/hero_select.tscn").instantiate()
	add_child(crowded)
	await _settle()
	crowded._pick(2, &"sai")
	crowded._pick(2, &"kid")
	crowded._pick(4, &"siku")
	for seat in 6:
		crowded._cursor[seat] = seat * 2
	await _settle()
	await _shoot("hero_select_3v3.png")
	crowded.queue_free()
	GameManager.team_size = 1

	var stage_select: CanvasLayer = load("res://src/ui/stage_select.tscn").instantiate()
	add_child(stage_select)
	await _settle()
	await _shoot("stage_select.png")
	get_tree().quit()

func _settle() -> void:
	for i in 8:
		await get_tree().process_frame

func _shoot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT_DIR, file])
	print("wrote ", file)
