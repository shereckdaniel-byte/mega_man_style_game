## Drives stage 1 from spawn to the boss door and reports whether it got there.
##
##   xvfb-run -a godot --script res://tools/playthrough.gd -- <out_dir>
##
## A traversal check, not a difficulty check. It answers one question — is the
## stage finishable at all — which is the question authored geometry gets wrong
## in ways that look fine from a screenshot. Three real bugs came out of it: a
## pit that did not kill during i-frames, a kill that left the player walking,
## and a three-tile step in a corridor with no way round.
##
## It reads the deck ahead of the player and jumps for gaps and steps, rather
## than hopping on a fixed cadence. That matters: a fixed cadence walks into
## gaps a player would clear, so it reports failures the stage does not have. A
## bot that jumps when there is something to jump means a failure is the stage's.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const DECK_ROW := 11
const DECK_DEPTH := 2
## Cells ahead to look for a hole or a step.
##
## One, not two. Jumping when the hole is two cells away launches the arc a cell
## early and lands it *in* the gap: a jump takes about 40 frames and covers 3.4
## tiles, so starting it 2 tiles before a 2-tile gap puts the landing right in
## the middle. This cost a wrong conclusion once -- the bot fell in, and the
## stage looked unfinishable when the bot was simply jumping too soon.
const LOOKAHEAD := 1

## Frames to hold jump. The player's cut-jump means a short hold is a short hop;
## this is long enough for a full arc.
const JUMP_HOLD := 16
## Frames without horizontal progress before we call it stuck.
const STUCK_FRAMES := 900

var _stage: Node
var _player: Player
var _deck: TileMapLayer
var _tile := 72.0
var _jump_left := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	for i in 60:
		await process_frame

	_stage = current_scene
	_player = _stage.get_node("Player")
	_deck = _stage.get_node("Boardwalk")
	var autoload := root.get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_tile = autoload.player.tile_size()

	var state := root.get_node_or_null(^"/root/GameState")
	if state != null:
		state.lives = 99

	var goal: float = _stage.boss_door_position().x
	var deaths := [0]
	_player.died.connect(func() -> void: deaths[0] += 1)
	_stage.room_changed.connect(func(r: Room) -> void: print("  entered %s" % r.name))
	print("goal_x=%.0f  rooms=%d" % [goal, _stage.rooms().size()])

	var best: float = _player.global_position.x
	var stuck := 0
	var reached := false
	for frame in 9000:
		await process_frame
		if _stage.is_transitioning():
			_release()
			continue
		_drive()
		var x: float = _player.global_position.x
		if x > best + 4.0:
			best = x
			stuck = 0
		else:
			stuck += 1
		if x >= goal:
			reached = true
			print("REACHED the boss door at frame %d" % frame)
			break
		if frame % 60 == 0:
			print("  f%-5d x=%-6.0f y=%-6.0f cell=%-4d hp=%-3d %-6s floor=%s"
				% [frame, _player.global_position.x, _player.global_position.y,
					_cell_x(), _player.health.current,
					_player.state_machine.current_name(), _player.is_on_floor()])
		if stuck > STUCK_FRAMES:
			print("STUCK at x=%.0f for %d frames" % [x, stuck])
			break
	_release()

	print("result: reached=%s  x=%.0f/%.0f  room=%s  deaths=%d  hp=%d"
		% [reached, _player.global_position.x, goal, _stage.room.name,
			deaths[0], _player.health.current])

	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		root.get_texture().get_image().save_png("%s/playthrough.png" % args[0])
	quit(0 if reached else 1)


## One frame of input: always walk right, jump when the deck ahead demands it.
func _drive() -> void:
	Input.action_press(&"move_right")

	if _jump_left > 0:
		_jump_left -= 1
		if _jump_left == 0:
			Input.action_release(&"jump")

	if not _player.is_on_floor() or _jump_left > 0:
		return

	if _hole_ahead() or _step_ahead():
		Input.action_press(&"jump")
		_jump_left = JUMP_HOLD


func _cell_x() -> int:
	return int(floor(_player.global_position.x / _tile))


func _solid(cell: Vector2i) -> bool:
	return _deck.get_cell_source_id(cell) != -1


## No deck under the next couple of cells: jump the gap.
func _hole_ahead() -> bool:
	for step in range(1, LOOKAHEAD + 1):
		var x := _cell_x() + step
		var floored := false
		for y in range(DECK_ROW, DECK_ROW + DECK_DEPTH):
			if _solid(Vector2i(x, y)):
				floored = true
		if not floored:
			return true
	return false


## Deck at head height ahead: jump the step.
func _step_ahead() -> bool:
	var x := _cell_x() + 1
	return _solid(Vector2i(x, DECK_ROW - 1)) or _solid(Vector2i(x, DECK_ROW - 2))


func _release() -> void:
	for action in [&"move_right", &"jump", &"shoot"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
