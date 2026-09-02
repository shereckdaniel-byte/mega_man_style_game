## A playable stage: one active room, one camera, and the spawn markers in it.
##
## The markers are ticked from here rather than each polling for the camera
## itself. A room can hold dozens, and they all have to make the spawn decision
## against the same view rectangle on the same frame — two markers sitting on
## the same boundary that read the camera at different points in the frame can
## disagree, and the symptom is one enemy of a pair flickering.
class_name Stage
extends Node2D

signal room_changed(room: Room)

var camera: StageCamera
var room: Room
var player: Player

var _markers: Array[SpawnMarker] = []


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
	if camera == null:
		return
	var view := camera.view_rect()
	for marker in _markers:
		if is_instance_valid(marker):
			marker.update_for_view(view)


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
