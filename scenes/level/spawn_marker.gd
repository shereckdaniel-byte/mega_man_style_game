## Where an enemy comes from.
##
## Enemies are authored as markers, never as instances (ARCHITECTURE section
## 5.5). The marker spawns its enemy when the camera gets close, frees it when
## the camera leaves, and re-arms — so scrolling back and forth gives a fresh
## enemy every time.
##
## That is the original's exact behaviour and it is deliberate, not a bug to fix
## later: it is what makes farming health drops possible, and level design
## assumes it. An enemy that stayed dead once killed would change how a corridor
## plays on the way back.
##
## The asymmetry between the two thresholds is the important part. Spawning at
## 16 px beyond the view and despawning at 32 px means an enemy sitting exactly
## on the boundary does not spawn-despawn-spawn every frame as the camera
## jitters by a pixel. One threshold would do exactly that.
class_name SpawnMarker
extends Node2D

## Distance beyond the view at which the enemy appears, in NES pixels.
const SPAWN_MARGIN_NES := 16.0
## Distance beyond the view at which it is freed. Must exceed SPAWN_MARGIN_NES,
## and `tests/test_rooms.gd` asserts it.
const DESPAWN_MARGIN_NES := 32.0

@export var enemy_scene: PackedScene
## Handed to the spawned enemy. A persistent enemy is spawned once and never
## despawned — bosses, mini-bosses, gimmick platforms.
@export var persistent: bool = false
## Faces left when false, which is how most markers are placed.
@export var faces_right: bool = false

var _live: Node2D = null
## True once the enemy this marker made was *killed* rather than despawned.
##
## Without this the marker re-arms the instant the corpse is freed and spawns a
## replacement on the next frame, so a player could stand still and farm one
## enemy forever. The original makes you scroll it off screen and back, and that
## is the whole point of the rule.
var _spent := false
var _scale := 4.5


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_scale = autoload.player.world_scale


## Called once per frame by the stage with the camera's clamped view rectangle.
##
## Driven by the stage rather than by each marker polling for the camera: a room
## can hold dozens of markers and they must all make the decision against the
## same view, on the same frame, or two markers on the same boundary can
## disagree.
func update_for_view(view: Rect2) -> void:
	if enemy_scene == null:
		return
	var far := not view.grow(DESPAWN_MARGIN_NES * _scale).has_point(global_position)

	if is_instance_valid(_live):
		if not persistent and far:
			var enemy := _live
			# Cleared before despawning so the freed instance is never mistaken
			# for a kill on the next frame.
			_live = null
			if enemy.has_method("despawn"):
				enemy.despawn()
			else:
				enemy.queue_free()
		return

	# NOTE: death is reported by the enemy calling mark_spent(), not detected
	# here. The obvious version -- "a reference that is non-null but invalid is a
	# corpse" -- cannot work: on Godot 4.7 a freed object reference compares
	# EQUAL to null, so a killed enemy and a cleared slot are indistinguishable
	# by inspection. Verified directly: after queue_free() and two frames,
	# `n != null` is false and `is_instance_valid(n)` is false.

	# Leaving the despawn range is what re-arms a spent marker, which is exactly
	# the "scroll it off screen and back" the rule is about.
	if far:
		_spent = false
		return

	if not _spent and view.grow(SPAWN_MARGIN_NES * _scale).has_point(global_position):
		_spawn()


## Called by an enemy being despawned, so the marker can fire again immediately
## when the camera returns. Death does not call this -- see `_spent`.
func rearm() -> void:
	_live = null
	_spent = false


func live_enemy() -> Node2D:
	return _live if is_instance_valid(_live) else null


## Whether this marker would spawn if the camera arrived now. A spent marker is
## not armed: its enemy was killed and the camera has not left since.
func is_armed() -> bool:
	return not is_instance_valid(_live) and not _spent


## Called by an enemy that was killed. Leaves the marker empty but NOT armed, so
## it will not fire again until the camera has left and come back.
func mark_spent() -> void:
	_live = null
	_spent = true


func is_spent() -> bool:
	return _spent


func _spawn() -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_error("SpawnMarker at %s: scene is not a Node2D" % get_path())
		return
	enemy.global_position = global_position
	if enemy is Enemy:
		var typed := enemy as Enemy
		typed.spawn_marker = self
		typed.persistent = persistent
	if "facing" in enemy:
		enemy.set("facing", 1 if faces_right else -1)
	get_parent().add_child(enemy)
	_live = enemy
