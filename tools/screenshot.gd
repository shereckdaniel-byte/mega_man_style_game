## Renders a scene offscreen and writes PNGs, so a change can be looked at
## without a desktop.
##
##   xvfb-run -a godot --script res://tools/screenshot.gd -- <out_dir>
##
## The first four shots drive the player from spawn with input alone. The rest
## place the player at a known tile first: walking there from spawn puts it
## against the test room's steps, where a slide ends on frame one against the
## wall and the shot shows a walk pose instead of the move it is named after.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const SCENE := "res://scenes/stages/test_room/test_room.tscn"
const SETTLE_FRAMES := 20
## Mirrors test_room.gd's GROUND_ROW; the placed shots stand on it.
const TestRoomGroundRow := 13.0


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
	_release_all()

	var player := _find_player(scene)
	if player == null:
		push_warning("no Player in the scene; skipping the placed shots")
		quit(0)
		return

	# Flat ground well clear of the steps, so the slide runs its full length.
	await _place(player, 13.5)
	await _slide(player)
	await _shot(out_dir, "05_slide_flat")

	# Into the slide-only tunnel at tiles 15-18, the reason the move exists.
	await _place(player, 14.0)
	await _slide(player, 16)
	await _shot(out_dir, "06_slide_tunnel")

	# The ladder column is addressed by its centre, at tile 21.5; standing at 21.0
	# leaves the player on the very edge of the Area2D and Idle never sees it.
	await _place(player, 21.5)
	Input.action_press(&"move_up")
	await _frames(40)
	_report(player, "07_climbing")
	await _shot(out_dir, "07_climbing")
	_release_all()

	# Shooting is a suffix on the state, and nothing fires the buster until M3,
	# so drive the shoot pose directly.
	await _place(player, 13.5)
	Input.action_press(&"move_right")
	player.note_shot_fired()
	await _frames(10)
	_report(player, "08_walk_shoot")
	await _shot(out_dir, "08_walk_shoot")

	player.note_shot_fired()
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(8)
	_report(player, "09_jump_shoot")
	await _shot(out_dir, "09_jump_shoot")
	_release_all()

	# Teleport is the one place the controller does wait on the animation.
	await _place(player, 13.5)
	player.state_machine.transition_to(&"Teleport")
	await _frames(6)
	_report(player, "10_teleport_in")
	await _shot(out_dir, "10_teleport_in")

	quit(0)


const ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"shoot"]


func _release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _find_player(node: Node) -> Player:
	if node is Player:
		return node as Player
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


## Drops the player onto the ground row at a given tile column and lets it settle.
func _place(player: Player, tile_x: float) -> void:
	_release_all()
	var tuning: PlayerTuning = player.tuning
	var tile := tuning.tile_size()
	player.velocity = Vector2.ZERO
	player.position = Vector2(tile_x * tile, TestRoomGroundRow * tile)
	player.state_machine.transition_to(&"Idle")
	await _frames(12)


func _slide(player: Player, hold: int = 10) -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(hold)
	_report(player, "slide")


## Prints the state and animation actually captured, so a shot that silently
## fell back to Idle is visible in the log rather than only in the image.
func _report(player: Player, label: String) -> void:
	if player.state_machine.current != null:
		print("   %-14s state=%s anim=%s" % [
			label, player.state_machine.current.name, player.sprite.animation])


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
