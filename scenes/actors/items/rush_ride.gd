## The rideable half of the utility set: Rush Jet and Rush Marine.
##
## One class for both, because they are the same object with different axes and
## one condition. The difference between them is what a difference between two
## items should be -- where they work and which way they go -- and putting it in
## two files would mean two copies of the carrying machinery.
##
##   * **Jet** flies forward at a constant speed, anywhere, and is the answer to
##     a gap the level did not mean to be crossed.
##   * **Marine** works **only inside water**, and steers on both axes. Outside
##     it, it sits still and does nothing, which is a refusal the player can see
##     rather than an item that quietly wastes its ammo.
##
## ### It is an AnimatableBody2D, which is why the courier exists
##
## A thing the player stands on has to be a body, and `sync_to_physics` is what
## makes `move_and_slide` carry a rider with no code on the rider's side -- the
## same trick `MovingPlatform` turns on. A `WeaponShot` is an `Area2D` and can
## never be this, which is the whole reason a utility weapon fires a courier
## instead of firing the item.
##
## ### Fuel, not a timer
##
## It runs out after `FUEL_FRAMES` **of carrying somebody**. A ride that expired
## on a wall clock would punish a player for looking before they leapt; one that
## only spends fuel while it is being used charges for the thing it is for.
class_name RushRide
extends AnimatableBody2D

## What a ride is allowed to do.
enum Mode {
	## Forward only, anywhere. The Jet.
	FLIGHT,
	## Both axes, water only. The Marine.
	SUBMARINE,
}

@export var mode: Mode = Mode.FLIGHT

## Travel speed in NES px/frame.
##
## **Above the player's walk of 1.375**, or riding would be slower than walking
## and the item would be a worse way to do a thing they can already do. Below a
## full-speed fall, so it never outruns the camera.
const SPEED_PF := 2.4

## Frames of carrying before it gives out. About eight seconds, which crosses
## any room in the game and does not cross two.
const FUEL_FRAMES := 480
## Frames of the fuel spent blinking, so it says it is going before it goes.
const BLINK_FRAMES := 90
const BLINK_PERIOD := 6
## How long it waits for a rider before giving up, if nobody ever gets on.
const IDLE_FRAMES := 300

const SIZE_NES := Vector2(28.0, 7.0)

const HULL := Color(0.86, 0.28, 0.26)
const TRIM := Color(0.94, 0.92, 0.88)
const FLAME := Color(0.98, 0.78, 0.30)
const DEAD := Color(0.42, 0.40, 0.44)

var _tuning: PlayerTuning
var _fuel := FUEL_FRAMES
var _idle := 0
var _heading := 1
var _rider: Player = null
var _sensor: Area2D
var _in_water := false


## Sets which way it sets off. The courier hands over the player's facing, so a
## ride always leaves the way the player was looking.
func set_heading(value: int) -> void:
	_heading = signi(value) if value != 0 else 1


func fuel_left() -> int:
	return _fuel


func has_rider() -> bool:
	return _rider != null and is_instance_valid(_rider)


## Whether it can move right now. False for a Marine out of water, which is the
## visible refusal rather than a wasted summon.
func can_run() -> bool:
	return mode != Mode.SUBMARINE or _in_water


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	# The same arrangement `MovingPlatform` uses: a body on the platform layer
	# whose movement is motion rather than teleportation, so a rider is carried
	# by their own `move_and_slide`.
	sync_to_physics = true
	collision_layer = Layers.bit(Layers.PLATFORM)
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_NES * _tuning.world_scale
	shape.shape = rect
	add_child(shape)

	# A separate sensor for "is somebody on me", because the body itself cannot
	# report its own riders -- and for the Marine, "am I in water".
	_sensor = Area2D.new()
	_sensor.name = "Sensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = Layers.bit(Layers.PLAYER_BODY)
	var sense_shape := CollisionShape2D.new()
	var sense_rect := RectangleShape2D.new()
	# Taller than the hull, so a player standing on top is inside it.
	sense_rect.size = Vector2(SIZE_NES.x, SIZE_NES.y + 26.0) * _tuning.world_scale
	sense_shape.shape = sense_rect
	sense_shape.position = Vector2(0.0, -sense_rect.size.y * 0.35)
	_sensor.add_child(sense_shape)
	add_child(_sensor)
	z_index = 4
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_water()
	_update_rider()

	if not has_rider():
		_idle += 1
		if _idle >= IDLE_FRAMES:
			queue_free()
			return
		queue_redraw()
		return
	_idle = 0

	if not can_run():
		# A Marine on dry land: it holds the player up and goes nowhere, which
		# is a refusal they can see.
		queue_redraw()
		return

	_fuel -= 1
	if _fuel <= 0:
		queue_free()
		return

	var step := _tuning.px_s(SPEED_PF) * delta
	position.x += float(_heading) * step
	if mode == Mode.SUBMARINE:
		# Both axes, and steered: the Marine is the only thing in the game the
		# player drives rather than rides.
		var vertical := 0.0
		if Input.is_action_pressed(&"move_up"):
			vertical -= 1.0
		if Input.is_action_pressed(&"move_down"):
			vertical += 1.0
		position.y += vertical * step
	queue_redraw()


## Whether the ride is inside a water volume. Asked of the volumes rather than
## of a flag they set, so a ride that drifts out of one notices on the next
## frame with nothing having to tell it.
func _update_water() -> void:
	_in_water = false
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if not (child is WaterVolume):
			continue
		var pool := child as WaterVolume
		var tile := _tuning.tile_size()
		var box := Rect2(pool.global_position,
			Vector2(pool.width_tiles, pool.depth_tiles) * tile)
		if box.has_point(global_position):
			_in_water = true
			return


func _update_rider() -> void:
	_rider = null
	if _sensor == null or not _sensor.monitoring:
		return
	for body in _sensor.get_overlapping_bodies():
		if body is Player:
			_rider = body as Player
			return


func _draw() -> void:
	var blinking := _fuel <= BLINK_FRAMES and (_fuel / BLINK_PERIOD) % 2 == 1
	if blinking:
		return
	var size := SIZE_NES * _tuning.world_scale
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, HULL if can_run() else DEAD)
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x, size.y * 0.3)), TRIM)
	if mode == Mode.SUBMARINE:
		# A dome, so a Marine is not a Jet in a different room.
		draw_circle(Vector2(0.0, -size.y * 0.45), size.y * 0.55, TRIM)
	if has_rider() and can_run():
		# Thrust, behind it.
		var back := -float(_heading) * size.x * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(back, -size.y * 0.3),
			Vector2(back, size.y * 0.3),
			Vector2(back - float(_heading) * size.x * 0.35, 0.0),
		]), FLAME)
