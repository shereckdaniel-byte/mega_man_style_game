## A block that gives way under you.
##
## Stand on it and it shakes for `warn_frames`, falls, and is gone for
## `respawn_frames` before coming back where it was. The warning is the whole
## design: a block that vanished the instant you touched it would be a trap
## rather than a challenge, and the player would learn it by dying instead of by
## looking.
##
## Also the groundwork for Mirror Field's disappearing blocks (PLAN section 4) --
## those are the same timed geometry on a fixed cycle instead of a triggered one.
class_name CrumblingBlock
extends AnimatableBody2D

signal crumbled()
signal restored()

## Named Phase, not State: `State` is a global class_name in this project
## (scripts/core/state.gd), and an enum of that name inside a class makes every
## reference to it ambiguous -- the parser rejects the whole file with an error
## that points at the *test* using it rather than at the declaration.
enum Phase { SOLID, WARNING, GONE }

@export var size_tiles := Vector2(1.0, 1.0):
	set(value):
		size_tiles = Vector2(maxf(value.x, 0.25), maxf(value.y, 0.25))
		if is_inside_tree():
			_rebuild()

## Frames between being stood on and giving way. About a third of a second --
## long enough to read and react, short enough to feel urgent.
@export var warn_frames: int = 22
## Frames it stays gone. Long enough that a player cannot simply wait on the
## spot for it, short enough that a missed jump is not a long walk back.
@export var respawn_frames: int = 90
## How far it shakes while warning, in px.
@export var shake_px := 2.5

## The stage's own terrain, borrowed so a crumbler is made of the deck it was
## cut from. 16 px tiles: `wang_12` is the top surface, `wang_0` the interior.
##
## **A playtester's note on the moving platforms was that they "should look like
## the floor below or very close", and these were the last thing in the kit that
## did not.** A flat tan slab on a rust deck reads as placeholder. But drawing
## them as *plain* deck goes too far the other way: rendered side by side, plain
## deck tiles make the blocks vanish into the walkway on two stages out of three,
## and a trap you cannot see is the exact failure the crack exists to prevent.
##
## So they are **damaged deck**: the same tiles, dulled and darkened, corners
## bitten out, and a crack at roughly triple the old line weight -- a hairline
## that read on a flat slab disappears on a textured one. The material says
## "part of this floor" and the damage says "not for long".
const TOP_TILE := Rect2(48.0, 0.0, 16.0, 16.0)
const CORE_TILE := Rect2(32.0, 16.0, 16.0, 16.0)
## Art pixels per tile in the source tilesets (SPRITES.md section 8).
const ART_TILE := 16.0

const SOLID_FACE := Color(0.55, 0.50, 0.42)
const WARN_FACE := Color(0.78, 0.58, 0.34)
const EDGE := Color(0.25, 0.22, 0.18)
## Dulling laid over the borrowed tiles, and the bitten-out corners.
const SPOILED := Color(0.18, 0.13, 0.11, 0.42)
const BITE := Color(0.06, 0.04, 0.04, 0.85)
const CRACK := Color(0.05, 0.03, 0.03, 0.9)

var _atlas: Texture2D

var phase: Phase = Phase.SOLID
var _frames := 0
var _origin := Vector2.ZERO
var _shape: CollisionShape2D
var _sensor: Area2D


func _ready() -> void:
	collision_layer = Layers.bit(Layers.PLATFORM)
	collision_mask = 0
	sync_to_physics = true
	_origin = position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_atlas = _stage_atlas()
	_rebuild()
	_build_sensor()


## The terrain atlas of whatever stage this block is in, or null.
##
## Found by walking up to the stage rather than injected, so a block dropped
## into a bare test tree still builds -- it simply falls back to the flat face
## below, which is what shipped before this and is still what a stage with no
## tileset gets.
func _stage_atlas() -> Texture2D:
	var node := get_parent()
	while node != null:
		if node.has_method("stage_tile_set"):
			var set: TileSet = node.call("stage_tile_set")
			if set != null and set.get_source_count() > 0:
				var source := set.get_source(set.get_source_id(0)) as TileSetAtlasSource
				if source != null:
					return source.texture
		node = node.get_parent()
	return null


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


func world_size() -> Vector2:
	return size_tiles * tile_size()


func is_solid() -> bool:
	return phase != Phase.GONE


## Starts the countdown. Called by the sensor, and directly by tests.
func trigger() -> void:
	if phase != Phase.SOLID:
		return
	phase = Phase.WARNING
	_frames = 0


func _physics_process(_delta: float) -> void:
	_frames += 1
	match phase:
		Phase.WARNING:
			# Shake in place. Position, not rotation: the collision shape moves
			# with it, and a rotating block would change what it is standing on.
			position = _origin + Vector2(sin(float(_frames) * 1.4) * shake_px, 0.0)
			if _frames >= warn_frames:
				_fall()
		Phase.GONE:
			if _frames >= respawn_frames:
				_restore()
		Phase.SOLID:
			pass


func _fall() -> void:
	phase = Phase.GONE
	_frames = 0
	position = _origin
	# Collision off rather than the node hidden: a hidden block still holds the
	# player up, which is the worst version of this -- an invisible floor.
	_set_collision(false)
	visible = false
	crumbled.emit()


func _restore() -> void:
	phase = Phase.SOLID
	_frames = 0
	position = _origin
	_set_collision(true)
	visible = true
	restored.emit()


func _set_collision(value: bool) -> void:
	collision_layer = Layers.bit(Layers.PLATFORM) if value else 0
	if _shape != null:
		_shape.set_deferred(&"disabled", not value)


func _rebuild() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = world_size()
	_shape.shape = rect
	_shape.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	queue_redraw()


## A thin sensor sitting on the block's top face.
##
## The block cannot notice the player itself -- an AnimatableBody2D reports what
## it collides with only from the mover's side, and the player is the one doing
## the moving. So the block watches for a body arriving on its lid.
func _build_sensor() -> void:
	_sensor = Area2D.new()
	_sensor.name = "Lid"
	_sensor.collision_layer = 0
	_sensor.collision_mask = Layers.bit(Layers.PLAYER_BODY)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var size := world_size()
	rect.size = Vector2(size.x * 0.9, maxf(size.y * 0.35, 8.0))
	shape.shape = rect
	shape.position = Vector2(size.x * 0.5, 0.0)
	_sensor.add_child(shape)
	add_child(_sensor)
	_sensor.body_entered.connect(func(_body: Node2D) -> void: trigger())


func _draw() -> void:
	if phase == Phase.GONE:
		return
	var size := world_size()

	if _atlas == null:
		var face := WARN_FACE if phase == Phase.WARNING else SOLID_FACE
		draw_rect(Rect2(Vector2.ZERO, size), face)
		draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, maxf(size.y * 0.08, 2.0))
	else:
		_draw_deck(size)
		_draw_damage(size)
		if phase == Phase.WARNING:
			draw_rect(Rect2(Vector2.ZERO, size), Color(WARN_FACE, 0.45))

	_draw_crack(size)


## The block's face, tiled out of the stage's terrain: surface tile on the top
## row, interior below, so a block taller than one tile still reads as a cut
## piece of deck rather than as a repeated lid.
func _draw_deck(size: Vector2) -> void:
	var step := tile_size()
	var y := 0.0
	while y < size.y - 0.5:
		var source := TOP_TILE if y < 0.5 else CORE_TILE
		var x := 0.0
		while x < size.x - 0.5:
			draw_texture_rect_region(_atlas, Rect2(Vector2(x, y),
				Vector2(minf(step, size.x - x), minf(step, size.y - y))), source)
			x += step
		y += step


func _draw_damage(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SPOILED)
	var bite := size.x * 0.22
	for corner in [Vector2(0.0, 0.0), Vector2(size.x, 0.0)]:
		var inward := 1.0 if corner.x < 1.0 else -1.0
		draw_colored_polygon(PackedVector2Array([
			corner,
			corner + Vector2(inward * bite, 0.0),
			corner + Vector2(0.0, bite * 0.8),
		]), BITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.03, 0.75),
		false, maxf(size.y * 0.05, 2.0))


## A fracture, so a crumbler is distinguishable from solid terrain *before* it
## is stood on.
##
## Thin and jagged rather than bold -- but three times the weight it was, because
## the block is now made of the deck's own pixels and a hairline drawn on a flat
## slab is invisible on a textured one. Still one crack and one branch: two say
## "damaged", three start to say "pattern".
func _draw_crack(size: Vector2) -> void:
	var hair := maxf(size.y * 0.075, 4.0) if _atlas != null else maxf(size.y * 0.025, 1.0)
	var ink := CRACK if _atlas != null else EDGE
	var mid := size.x * 0.5
	draw_polyline(PackedVector2Array([
		Vector2(mid + size.x * 0.06, size.y * 0.08),
		Vector2(mid - size.x * 0.02, size.y * 0.34),
		Vector2(mid + size.x * 0.05, size.y * 0.58),
		Vector2(mid - size.x * 0.04, size.y * 0.92),
	]), ink, hair)
	draw_line(Vector2(mid - size.x * 0.02, size.y * 0.34),
		Vector2(mid - size.x * 0.22, size.y * 0.52), ink, hair)
