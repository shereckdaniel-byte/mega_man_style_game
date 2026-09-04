## Shoots every room of a stage, so the whole level can be looked at at once.
##
##   xvfb-run -a godot --script res://tools/stage_map.gd -- <out_dir> [stage=<name>]
##
## One PNG per room, named `<index>_<room>.png`, plus a second shot of each dark
## room with the lights out (`<index>_<room>_dark.png`). Stitching them onto the
## room grid is left to whatever is looking at them -- the room table already
## says which column and band each one belongs in, and a contact sheet laid out
## that way is a picture of the stage's shape as well as its contents.
##
## **It teleports rather than plays.** The playthrough bot exists to answer "can
## this be finished"; this answers "what does it look like", and driving a player
## through eight rooms to photograph them would take four minutes and put the
## camera wherever the run happened to end. So the player is placed at each
## room's spawn-ish point and the stage is told which room is active, by the same
## three calls the door transition makes at its end.
##
## Enemies are given a moment to spawn before the shutter: the spawn rule only
## places them when their marker enters the camera's view (ARCHITECTURE 5.5), so
## a shot taken on the frame the camera arrives is a shot of an empty room.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const STAGES := {
	"dawn_boardwalk": "res://scenes/stages/dawn_boardwalk/dawn_boardwalk.tscn",
	"substation": "res://scenes/stages/substation/substation.tscn",
	"breakers": "res://scenes/stages/breakers/breakers.tscn",
}

## Frames to let the stage build, the backdrop swap and the markers spawn.
const SETTLE_FRAMES := 30
## Where in the room to stand, as a fraction of its width. Left of centre, so the
## player is in shot without covering the middle of the room.
const STAND_AT := 0.28

var _stage: Node
var _out := "user://"


func _initialize() -> void:
	_run()


func _run() -> void:
	await physics_frame
	var stage_name := "dawn_boardwalk"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("stage="):
			stage_name = argument.substr(6).strip_edges()
		else:
			_out = argument
	if not STAGES.has(stage_name):
		push_error("unknown stage %s" % stage_name)
		quit(1)
		return

	change_scene_to_file(STAGES[stage_name])
	for i in 60:
		await physics_frame
	_stage = current_scene

	var state := root.get_node_or_null(^"/root/GameState")
	if state != null:
		state.lives = 99

	var rooms: Array = _stage.rooms()
	print("%s: %d rooms" % [stage_name, rooms.size()])
	for index in rooms.size():
		await _shoot_room(stage_name, index, rooms[index], false)
		if _is_dark(index):
			await _shoot_room(stage_name, index, rooms[index], true)
	quit(0)


func _is_dark(index: int) -> bool:
	var table: Array = _stage.room_table()
	return bool(table[index].get("dark", false))


## Puts the player in a room, tells the stage it is the active one, and shoots it.
func _shoot_room(stage_name: String, index: int, room: Room, dark: bool) -> void:
	var player: Player = _stage.get_node("Player")
	var bounds := room.world_bounds()
	var tile: float = _stage.tile_size()
	player.global_position = Vector2(
		bounds.position.x + bounds.size.x * STAND_AT,
		float(_stage.room_deck_row(index)) * tile - tile)
	player.velocity = Vector2.ZERO

	# The three things a finished transition does. Called directly because there
	# is no door being walked through.
	_stage.room = room
	_stage.camera.enter_room(room)
	_stage.room_changed.emit(room)
	_stage.refresh_markers()

	await _frames(SETTLE_FRAMES)

	# Dark rooms are shot twice: once lit by the arc flash, which is the only
	# time their geometry is visible, and once in the dark, which is what the
	# room is actually like to play. Neither on its own is an honest picture.
	var gloom: DarkRoom = _stage.get("_dark") if _stage.has_method("dark_room") else null
	if gloom != null:
		await _hold_dark(gloom, dark)

	var suffix := "_dark" if dark else ""
	await _shot("%02d_%s%s" % [index, _slug(room.name), suffix])


## Waits for the arc flash to be at its brightest, or at its darkest.
func _hold_dark(gloom: DarkRoom, dark: bool) -> void:
	for i in gloom.period_frames * 2:
		await physics_frame
		if dark:
			# Well past the flash, where the room has settled to its dark level.
			if gloom.cycle_frame() == gloom.flash_frames + 20:
				return
		elif gloom.is_flashing() and gloom.cycle_frame() >= gloom.flash_rise_frames:
			return


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out.rstrip("/"), name]
	var err := image.save_png(path)
	print("%s %s" % ["ok " if err == OK else "ERR", path])


func _slug(name: String) -> String:
	return name.to_lower().replace(" ", "_")


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
