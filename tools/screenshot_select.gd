## Renders the stage select offscreen and writes a PNG, plus the per-boss
## framing numbers the picture is there to show.
##
##   xvfb-run -a godot --script res://tools/screenshot_select.gd -- <out_dir>
##
## The measurements matter as much as the shot: the screen letterboxes each
## portrait into a fixed box with STRETCH_KEEP_ASPECT_CENTERED, so a character
## whose art is wide-and-short is capped by the box's *width* and still draws
## short. Printing fill-of-cell and drawn height side by side says whether a
## height difference on screen is the art's framing or the box's aspect.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const SCENE := "res://scenes/ui/stage_select.tscn"
const SETTLE_FRAMES := 12
## Mirrors StageSelect.CELL_SIZE minus the two label rows; see _build_cell.
const BOX := Vector2(300.0, 186.0)


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]

	_measure()

	var screen: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(screen)
	await _frames(SETTLE_FRAMES)
	await _shot(out_dir, "stage_select")
	quit(0)


func _measure() -> void:
	print("boss     anim            cell        opaque      fill%%   drawn h (px in a %dx%d box)"
		% [int(BOX.x), int(BOX.y)])
	for row in StageRoster.ENTRIES:
		var path: String = row["frames"]
		if not ResourceLoader.exists(path):
			print("%-8s  MISSING %s" % [row["boss"], path])
			continue
		var frames := load(path) as SpriteFrames
		var anim := BossPortrait._best_animation(frames)
		var image := frames.get_frame_texture(anim, 0).get_image()
		var cell := image.get_size()
		var used := image.get_used_rect().size
		# What the TextureRect actually draws: fit-inside, aspect kept.
		var scale: float = minf(BOX.x / float(used.x), BOX.y / float(used.y))
		print("%-8s %-15s %4dx%-4d  %4dx%-4d  %5.1f  %6.1f" % [
			row["boss"], anim, cell.x, cell.y, used.x, used.y,
			100.0 * float(used.y) / float(cell.y), float(used.y) * scale])


func _shot(dir_path: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [dir_path.rstrip("/"), name]
	var err := image.save_png(path)
	print("%s  %s (%dx%d)" % ["ok " if err == OK else "ERR", path, image.get_width(),
		image.get_height()])


func _frames(count: int) -> void:
	for i in count:
		await process_frame
