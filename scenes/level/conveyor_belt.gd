## Stack's gimmick: a stretch of deck that carries you.
##
## ### It is a constant, and that is the whole point
##
## Turbine Row's wind is a **cycle you time**: it lulls, it tells, it gusts, and
## the answer is almost always to wait for the lull. Building stage 6 on a
## second cyclic horizontal force would have made it stage 5 in different
## tiles -- the player would learn one skill and use it twice.
##
## So a belt never stops, never reverses and never warns, because it has nothing
## to warn about. **It is a fact about a piece of floor rather than an event.**
## The question it asks is not "when do I move" but "where do I stand", and the
## answers the stage is built out of are all spatial: a belt running at a pit is
## a floor you cannot idle on, two belts meeting are a seam that holds you, and a
## belt under a low ceiling is a slide whose length is not the one you learned.
##
## ### The fairness rules
##
## Same shape `WindZone`, `DarkRoom` and `RisingTide` are held to, because a
## force that moves the player is the easiest thing in this kit to build an
## impossible room out of:
##
##   1. **You can always walk against it.** `speed_pf` is under
##      `PlayerTuning.walk_speed_pf` by enough to leave over half the walk, so
##      upstream is slow and never impossible. A belt at or above the walk speed
##      is a wall that looks like a floor. `tests/test_conveyor_belt.gd` asserts
##      it against the real tuning rather than against the number here.
##   2. **It does not touch a jump.** The push applies only while the player is
##      on the floor. Ground movement here is instant-on/instant-off and air
##      control is full strength, so a belt changes the run-up and never the
##      arc -- which is exactly the trap the wind fell into, where a headwind
##      shortened a jump enough to make authored gaps uncrossable. A belt cannot
##      do that to a gap no matter how it is placed.
##   3. **It carries a player who is not walking**, unlike the wind, and that is
##      the difference between weather and machinery. Standing still on a belt
##      is a decision with a consequence; standing still in a gust is not.
##
## Rule 3 is what makes a belt running at a pit a real hazard, and rule 1 is what
## keeps it fair: the floor is taking you somewhere, and walking is enough to
## refuse.
class_name ConveyorBelt
extends Area2D

## The default carry speed, as a constant as well as an export so a stage can
## place a belt without instantiating one to read the default off.
const DEFAULT_SPEED_PF := 0.6

## Which way it runs: +1 for right, -1 for left.
@export var direction: int = 1

## How fast it carries, in NES px/frame.
##
## **Under `PlayerTuning.walk_speed_pf` (1.375), and by enough to leave over half
## the walk.** At 0.6 a player walking upstream makes 0.775 px/frame, which is
## 56% -- slow enough to feel like work, fast enough that crossing a room against
## the belt is not a minute of holding right. The same bound `WindZone.speed_pf`
## and `Gale.CROSSWIND_DRIFT_PF` are held to, arrived at the expensive way on
## stage 5.
@export var speed_pf: float = DEFAULT_SPEED_PF

@export var width_tiles: float = 4.0

## How far above the deck surface the belt looks for a player, in tiles.
##
## The box has to be tall enough to contain a standing player's origin, which
## sits at their feet, plus the slack `move_and_slide` leaves between a body and
## the floor it is resting on. Two tiles is comfortably more than either and
## comfortably less than a jump.
@export var height_tiles: float = 2.0

## Tread animation speed, in drawn segments per frame. Cosmetic, but not
## optional: a belt that does not visibly run is a floor that moves the player
## for no reason a player can see.
const TREAD_TILES := 0.75
const SCROLL_PER_FRAME := 0.06

const FRAME := Color(0.24, 0.22, 0.24)
const BELT := Color(0.36, 0.33, 0.34)
const TREAD := Color(0.52, 0.46, 0.44)
const HOT := Color(0.92, 0.52, 0.24)

var _tuning: PlayerTuning
var _player: Player = null
var _frames := 0


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	# The belt looks; the player is looked for. Nothing masks its own layer.
	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tile := _tuning.tile_size()
	rect.size = Vector2(width_tiles, height_tiles) * tile
	shape.shape = rect
	# Anchored at the belt's own origin, which the stage places at the left end
	# of the run on the deck's surface -- so the box sits *above* the deck and
	# reaches up, rather than being centred on the floor line.
	shape.position = Vector2(rect.size.x * 0.5, -rect.size.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = -5
	queue_redraw()


## The drift this belt writes, in NES px/frame. Signed by `direction`.
func drift_pf() -> float:
	return float(signi(direction)) * speed_pf


func has_rider() -> bool:
	return _player != null and is_instance_valid(_player)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


## Written every frame and cleared every frame by the player, the same contract
## `WindZone` uses -- so a belt that is freed, or left behind by a room change,
## simply stops writing and the carry ends on the next frame with nothing having
## to remember to switch it off.
##
## **Only while the player is actually standing.** In the air the belt has no
## grip, which is rule 2 and is what stops it from ever shortening a jump.
func _physics_process(_delta: float) -> void:
	_frames += 1
	queue_redraw()
	if not has_rider():
		return
	if _player.is_on_floor():
		_player.carry_drift_pf = drift_pf()


func _draw() -> void:
	var tile := _tuning.tile_size()
	var width := width_tiles * tile
	# A shallow band sitting on the deck surface, not a block: the belt is the
	# top of the floor rather than a thing standing on it.
	var depth := tile * 0.42
	draw_rect(Rect2(Vector2(0.0, -depth), Vector2(width, depth)), FRAME)
	draw_rect(Rect2(Vector2(0.0, -depth * 0.82), Vector2(width, depth * 0.64)), BELT)

	# The treads, scrolling the way the belt runs. This is the only thing that
	# says which direction it is, so it is drawn rather than implied.
	var pitch := TREAD_TILES * tile
	var offset := fposmod(float(_frames) * SCROLL_PER_FRAME * pitch
		* float(signi(direction)), pitch)
	var at := offset - pitch
	while at < width:
		var x := clampf(at, 0.0, width)
		var w := minf(pitch * 0.34, width - x)
		if w > 0.0:
			draw_rect(Rect2(Vector2(x, -depth * 0.78), Vector2(w, depth * 0.56)),
				TREAD)
		at += pitch

	# A hot seam along the lip, because this is an incinerator floor and the
	# stage needs one warm colour that is not an enemy.
	draw_rect(Rect2(Vector2(0.0, -depth), Vector2(width, depth * 0.16)),
		Color(HOT, 0.65))
