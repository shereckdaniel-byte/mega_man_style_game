## Renders a scene offscreen and writes PNGs, so a change can be looked at
## without a desktop.
##
##   xvfb-run -a godot --script res://tools/screenshot.gd -- <out_dir>
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const SCENE := "res://scenes/stages/test_room/test_room.tscn"
const SETTLE_FRAMES := 20


func _initialize() -> void:
	_capture()


func _capture() -> void:
	var out_dir := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]

	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	await _frames(SETTLE_FRAMES)
	await _shot(out_dir, "01_spawn")

	# Walk right into the ledges, then jump the 2-tile step.
	Input.action_press(&"move_right")
	await _frames(70)
	await _shot(out_dir, "02_walking")

	Input.action_press(&"jump")
	await _frames(8)
	Input.action_release(&"jump")
	await _frames(6)
	await _shot(out_dir, "03_jumping")

	Input.action_release(&"move_right")
	await _frames(40)

	# Slide: down + jump.
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	await _frames(4)
	Input.action_release(&"jump")
	await _frames(8)
	await _shot(out_dir, "04_sliding")

	quit(0)


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
