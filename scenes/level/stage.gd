## A playable stage: one active room, one camera, and the spawn markers in it.
##
## The markers are ticked from here rather than each polling for the camera
## itself. A room can hold dozens, and they all have to make the spawn decision
## against the same view rectangle on the same frame — two markers sitting on
## the same boundary that read the camera at different points in the frame can
## disagree, and the symptom is one enemy of a pair flickering.
class_name Stage
extends Node2D

## The player has beaten the stage and left it. Nothing listens yet -- the stage
## select that will is M6 -- but the stage has to *say* it is finished somewhere,
## or the exit sequence ends with the player floating above an empty room and no
## way to tell that anything concluded.
signal stage_cleared()

signal room_changed(room: Room)
signal transition_started(door: Door)
signal transition_finished(room: Room)

## Frames the camera takes to cross to the next room, and pixels the player is
## walked through the doorway. Both from ARCHITECTURE section 5.4.
const SLIDE_FRAMES := 32
const WALK_THROUGH_NES := 24.0

## How far the player is carried through a *vertical* doorway, in NES px.
##
## Much further than the horizontal step, and not for feel -- for geometry. A
## trigger fires when a body first overlaps it, and a climbing player overlaps a
## door on the boundary line with their **head**, which puts their feet a full
## body-height below it. Carrying them the horizontal 24 px leaves them still
## below the line they just crossed, straddling the boundary with the room
## already changed underneath them.
##
## 40 is the character's own 24 px, plus half a door, plus a margin.
const CLIMB_THROUGH_NES := 40.0

var camera: StageCamera
var room: Room
var player: Player

var _markers: Array[SpawnMarker] = []
var _transitioning := false


## Wires a stage that has already built its geometry. Call once the player, the
## room and the markers are all in the tree.
func begin(p_player: Player, p_room: Room) -> void:
	player = p_player
	room = p_room
	_markers = _find_markers(self)

	camera = StageCamera.new()
	camera.name = "StageCamera"
	add_child(camera)
	camera.follow(player)
	camera.enter_room(room)
	room_changed.emit(room)


func _physics_process(_delta: float) -> void:
	if camera == null or _transitioning:
		# Markers are frozen mid-transition. Ticking them while the camera slides
		# would spawn the whole of the next room during the slide and despawn the
		# whole of the outgoing one, which is a visible pop either side.
		return
	var view := camera.view_rect()
	for marker in _markers:
		if is_instance_valid(marker):
			marker.update_for_view(view)


func is_transitioning() -> bool:
	return _transitioning


## Runs the screen transition: freeze, slide, walk through, unfreeze.
##
## On rails from start to finish, which is what makes it read as a transition
## rather than as the camera catching up with a player who kept walking.
func begin_transition(door: Door) -> void:
	if _transitioning:
		return
	var next := door.target_room(self)
	if next == null:
		push_error("Door at %s names no room" % door.get_path())
		door.release()
		return
	_transitioning = true
	transition_started.emit(door)
	_run_transition(door, next)


func _run_transition(door: Door, next: Room) -> void:
	var tree := get_tree()
	player.set_frozen(true)

	# Everything the outgoing room spawned goes now. Freeing them after the
	# slide would show them being deleted on screen.
	_despawn_all()

	var scale_factor := 4.5
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		scale_factor = autoload.player.world_scale
	var through := CLIMB_THROUGH_NES if door.is_vertical() else WALK_THROUGH_NES
	var step := door.direction.normalized() * through * scale_factor

	var from := camera.global_position
	var player_from := player.global_position
	var player_to := player_from + step
	camera.begin_slide(next)
	var to := camera.slide_target(next, player_to)

	for frame in SLIDE_FRAMES:
		await tree.physics_frame
		if not is_instance_valid(player) or not is_instance_valid(camera):
			return
		var t := float(frame + 1) / float(SLIDE_FRAMES)
		# Smoothstep rather than linear: a linear slide starts and stops dead,
		# which reads as a jump cut at both ends.
		var eased := t * t * (3.0 - 2.0 * t)
		camera.global_position = from.lerp(to, eased)
		player.global_position = player_from.lerp(player_to, eased)

	camera.end_slide(next)
	room = next
	player.set_frozen(false)
	door.release()
	refresh_markers()
	_transitioning = false
	room_changed.emit(next)
	transition_finished.emit(next)


## Frees every live enemy, without crediting anyone with a kill.
func _despawn_all() -> void:
	for marker in _markers:
		if not is_instance_valid(marker):
			continue
		var enemy := marker.live_enemy()
		if enemy == null:
			continue
		marker.rearm()
		if enemy.has_method("despawn"):
			enemy.despawn()
		else:
			enemy.queue_free()


## Re-scans for markers. Needed after a door transition builds the next room.
func refresh_markers() -> void:
	_markers = _find_markers(self)


func markers() -> Array[SpawnMarker]:
	return _markers


func live_enemies() -> int:
	var n := 0
	for marker in _markers:
		if is_instance_valid(marker) and marker.live_enemy() != null:
			n += 1
	return n


func _find_markers(node: Node) -> Array[SpawnMarker]:
	var out: Array[SpawnMarker] = []
	for child in node.get_children():
		if child is SpawnMarker:
			out.append(child as SpawnMarker)
		else:
			out.append_array(_find_markers(child))
	return out
