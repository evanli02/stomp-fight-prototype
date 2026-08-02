extends Node
## Dev-only: boot the balance sheet and the training room, screenshot each, quit.
##   Godot --path . res://tools/screenshot_tools.tscn
## Writes into screenshots/ (gitignored).

const OUT_DIR := "res://screenshots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var sheet: CanvasLayer = load("res://src/ui/balance_sheet.tscn").instantiate()
	add_child(sheet)
	await _settle(10)
	await _shoot("balance_sheet.png")
	sheet.queue_free()

	# The training room seats 2v2: one driver plus three dummies.
	GameManager.team_size = 2
	MatchState.clear_players()
	var room: Node2D = load("res://src/stage/training_room.tscn").instantiate()
	add_child(room)
	await _settle(90)          # let the dummies walk somewhere first
	await _shoot("training_room.png")
	get_tree().quit()

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
	await get_tree().process_frame

func _shoot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [OUT_DIR, file])
	print("wrote ", file)
