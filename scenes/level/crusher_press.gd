## Breakers' gimmick: a hull press that slams down and grinds back up.
##
## **The grammar is the bosses', not the kit's.** Every other element in the M5a
## kit is either always dangerous (spikes) or always safe-if-you-are-quick
## (crumbles, movers). A crusher is the first piece of level that is dangerous
## *sometimes*, and the vocabulary for that already exists in this project:
## `BossPattern`'s tell -> act -> recover. So a press holds, shudders, drops,
## rests, and rises, and the shudder is structural rather than decorative --
## it is the frames in which a player is told to get out of the column.
##
## ### The cycle is a fact about the press, not a number a room supplies
##
## A room says *where* a press is and *when in the cycle* it starts. It does not
## get to say how long the cycle is. That is deliberate: stage 2's mover shipped
## with a 130-frame leg that was quick enough to walk a late rider off the lip,
## and the fix was to stop inventing timings per placement. Here the phases are
## constants, the two travelling phases are derived from the distance and a
## speed, and `cycle_frames()` is whatever those add up to. A room that wants two
## presses out of step offsets `phase_frames`; it cannot author an incoherent
## press.
##
## ### Why it kills rather than damages
##
## Same reason a spike does (see `Hazard`): a crusher that costs 4 HP is a
## damage race and reads as one, and the whole point of a press is that the
## room is asking for a decision rather than a health bar. What makes that fair
## is the tell, which is long, fixed, and happens with the press still up.
##
## ### The two rules the shape has to keep
##
## 1. **The kill volume is the underside, and only while the press is moving
##    down.** A press at rest is inert and solid -- you can stand on it, and if
##    it rests clear of the deck you can slide under it. That gives the cycle a
##    safe state, which is what makes it a timing puzzle instead of a wall.
## 2. **The teeth reach below the press's own body.** The solid box would
##    otherwise arrive first and Godot would simply shove the player into the
##    deck: squeezed, not killed, and stuck. The kill has to land before the
##    push does, which is the same arrangement ceiling spikes use.
class_name CrusherPress
extends AnimatableBody2D

## Phases, in order. `cycle_frames()` is their total.
enum Phase { HOLD, TELL, DROP, REST, RISE }

## Frames the press waits at the top before the tell. The gap in which a room is
## crossable without needing to read anything.
const HOLD_FRAMES := 54
## The tell. Long enough to leave the column from a standing start at the far
## side of the press: a walk is 1.375 NES px/frame, so 36 frames is 49 px, or
## three tiles. A press is never wider than that -- `MAX_PRESS_TILES`.
const TELL_FRAMES := 36
## Frames the press sits at the bottom. This is the window the room is actually
## asking about, so it is the most generous of the three fixed numbers.
const REST_FRAMES := 44

## Travel speeds in NES px/frame. The drop is faster than a full-speed run
## (1.375) by a wide margin, because a press you can outrun downward is not a
## press. The rise is slow so the reset reads as machinery rather than a snap.
const DROP_SPEED_PF := 7.0
const RISE_SPEED_PF := 1.5

## The widest a press may be, in tiles. Not a taste: `TELL_FRAMES` is sized to
## let a standing player walk clear of the press, and the arithmetic above
## assumes the press is no wider than the distance that walk covers.
const MAX_PRESS_TILES := 3.0

## How far the teeth reach below the press's own body, in tiles. See rule 2.
const TEETH_TILES := 0.34

## Shudder amplitude during the tell, in tiles. Small on purpose -- a press that
## visibly moves during its tell is a press that has started dropping.
const SHUDDER_TILES := 0.06

const FACE := Color(0.40, 0.36, 0.36)
const PLATE := Color(0.48, 0.42, 0.40)
const RIVET := Color(0.28, 0.25, 0.25)
const TOOTH := Color(0.74, 0.75, 0.80)
const TOOTH_EDGE := Color(0.30, 0.30, 0.34)
const EDGE := Color(0.17, 0.15, 0.16)
const RAIL := Color(0.32, 0.30, 0.31)
const RAIL_EDGE := Color(0.20, 0.18, 0.19)
const WARN := Color(0.92, 0.72, 0.20)

## Size in tiles. Anchored top-left like the rest of the kit.
@export var size_tiles := Vector2(3.0, 2.0)

## How far the press travels down, in tiles.
@export var drop_tiles := 6.0

## Offsets the cycle at spawn, so a row of presses can be staggered.
@export var phase_frames: int = 0

## Set false to leave it parked, for a press switched on by something else.
@export var running: bool = true

var _origin := Vector2.ZERO
var _frames := 0
var _shape: CollisionShape2D
var _teeth: Hazard


func _ready() -> void:
	# Layer 13 is `platform`, the same one the mover uses and the player's body
	# already masks. A press is a solid you can stand on when it is down.
	collision_layer = Layers.bit(Layers.PLATFORM)
	collision_mask = 0
	# Movement has to reach the physics server as motion, not as teleportation,
	# or a player standing on a rising press is left behind by it. Same reason
	# MovingPlatform is an AnimatableBody2D.
	sync_to_physics = true
	_origin = position
	_frames = phase_frames
	_rebuild()
	_apply()


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


func world_size() -> Vector2:
	return size_tiles * tile_size()


func drop_distance() -> float:
	return drop_tiles * tile_size()


## Frames the drop and the rise take, derived from the distance rather than
## authored. `tuning.px_s` is per second; a phase is counted in frames, so the
## conversion is distance in NES px over speed in NES px per frame.
func drop_frames() -> int:
	return maxi(int(ceil(drop_tiles * 16.0 / DROP_SPEED_PF)), 1)


func rise_frames() -> int:
	return maxi(int(ceil(drop_tiles * 16.0 / RISE_SPEED_PF)), 1)


func cycle_frames() -> int:
	return HOLD_FRAMES + TELL_FRAMES + drop_frames() + REST_FRAMES + rise_frames()


## Which phase the press is in at a given frame, and how far into it.
##
## Returned together because every caller needs both and deriving them twice
## from the same frame is how the drawing and the collision end up disagreeing
## about when the teeth are live.
func phase_at(frame: int) -> Array:
	var at := posmod(frame, cycle_frames())
	var spans := [
		[Phase.HOLD, HOLD_FRAMES],
		[Phase.TELL, TELL_FRAMES],
		[Phase.DROP, drop_frames()],
		[Phase.REST, REST_FRAMES],
		[Phase.RISE, rise_frames()],
	]
	for span: Array in spans:
		var length: int = span[1]
		if at < length:
			return [span[0], at, length]
		at -= length
	return [Phase.HOLD, 0, HOLD_FRAMES]


func phase() -> Phase:
	return phase_at(_frames)[0]


## How far down the press is, 0..1, at a given frame. Static and pure so a test
## can check the whole cycle without stepping physics for six seconds.
static func extension_at(frame: int, down: int, up: int) -> float:
	var cycle := HOLD_FRAMES + TELL_FRAMES + down + REST_FRAMES + up
	var at := posmod(frame, maxi(cycle, 1))
	at -= HOLD_FRAMES + TELL_FRAMES
	if at < 0:
		return 0.0
	if at < down:
		return clampf(float(at + 1) / float(maxi(down, 1)), 0.0, 1.0)
	at -= down
	if at < REST_FRAMES:
		return 1.0
	at -= REST_FRAMES
	return clampf(1.0 - float(at + 1) / float(maxi(up, 1)), 0.0, 1.0)


func extension() -> float:
	return extension_at(_frames, drop_frames(), rise_frames())


## The teeth bite only on the way down. Stated as its own method because it is
## rule 1, and because the drawing and the Hazard both have to agree on it.
func is_biting() -> bool:
	return phase() == Phase.DROP


func current_position() -> Vector2:
	var at := _origin + Vector2(0.0, drop_distance() * extension())
	if phase() == Phase.TELL:
		# The shudder is a wobble, not a descent: it must average to where the
		# press already is, or the tell moves the kill volume down early.
		var wobble := SHUDDER_TILES * tile_size()
		at.x += wobble * (1.0 if _frames % 4 < 2 else -1.0)
	return at


func _physics_process(_delta: float) -> void:
	if not running:
		return
	_frames += 1
	_apply()


func _apply() -> void:
	position = current_position()
	if _teeth != null:
		_teeth.monitoring = is_biting()
	queue_redraw()


func _rebuild() -> void:
	var size := world_size()
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size * 0.5

	# The kill volume, hanging below the body so it lands before the push does.
	# Drawn by this class rather than by the Hazard: a Hazard draws spike teeth,
	# and a press's underside is a different thing that happens to kill.
	if _teeth == null:
		_teeth = Hazard.new()
		_teeth.name = "Teeth"
		add_child(_teeth)
	_teeth.size_tiles = Vector2(size_tiles.x, TEETH_TILES)
	_teeth.position = Vector2(size.x * 0.5, size.y)
	_teeth.visible = false
	_teeth.monitoring = false
	queue_redraw()


func _draw() -> void:
	var size := world_size()
	var tile := tile_size()

	# The guide rails, drawn in the press's own space but offset back to where
	# the press hangs from. They are static in the world and the press is not, so
	# the offset is what keeps them nailed to the ceiling while the body moves.
	#
	# **The whole track is drawn, not just the exposed part.** The first version
	# drew only the length the press had descended, which meant a retracted press
	# had no rail at all and hung in the sky -- which is the fault a playtester
	# reported on stage 1 as "the turret is just floating in the air", arrived at
	# from the opposite direction. A press is a thing that runs in a track, and
	# the track is there whether or not the press has left the top of it.
	var overhead := _origin.y - position.y
	var track := drop_distance() + size.y
	var rail_w := maxf(tile * 0.18, 3.0)
	for at in [tile * 0.35, size.x - tile * 0.35 - rail_w]:
		var rect := Rect2(Vector2(at, overhead), Vector2(rail_w, track))
		draw_rect(rect, RAIL)
		draw_rect(rect, RAIL_EDGE, false, maxf(tile * 0.03, 1.0))

	# Body.
	draw_rect(Rect2(Vector2.ZERO, size), FACE)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.30)), PLATE)
	var rivet := maxf(tile * 0.06, 2.0)
	var step := tile * 0.5
	var x := step * 0.5
	while x < size.x:
		draw_circle(Vector2(x, size.y * 0.15), rivet, RIVET)
		x += step

	# A hazard stripe across the face, which is what says "this one is the one
	# that kills you" from across the room rather than on the frame it arrives.
	var band := Rect2(Vector2(0.0, size.y * 0.45), Vector2(size.x, size.y * 0.16))
	draw_rect(band, WARN if is_biting() or phase() == Phase.TELL else WARN.darkened(0.45))

	# The bottom teeth: blunt, wide and few, so they read as a press rather than
	# as the spike row Hazard draws.
	var tooth_h := TEETH_TILES * tile
	var count := maxi(int(round(size.x / tile)), 1)
	var width := size.x / float(count)
	for i in count:
		var left := width * float(i)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left, size.y),
			Vector2(left + width, size.y),
			Vector2(left + width * 0.72, size.y + tooth_h),
			Vector2(left + width * 0.28, size.y + tooth_h),
		]), TOOTH)
		draw_polyline(PackedVector2Array([
			Vector2(left, size.y),
			Vector2(left + width * 0.28, size.y + tooth_h),
			Vector2(left + width * 0.72, size.y + tooth_h),
			Vector2(left + width, size.y),
		]), TOOTH_EDGE, maxf(tile * 0.03, 1.0))

	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, maxf(tile * 0.05, 2.0))
