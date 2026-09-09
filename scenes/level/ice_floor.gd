## Cold Store's gimmick: a stretch of deck you cannot stop on quickly.
##
## ### It is neither a push nor a cycle, and that is the whole design
##
## Stage 5's wind is a **cycle you time**. Stage 6's belt is a **constant you
## fight**. Both of those *move* the player, and a third force that also moved
## them would be the same lesson a third time however differently it was
## dressed. Ice moves nobody: it takes away the one thing the controller has
## always guaranteed, which is that letting go stops you.
##
## Ground movement in this game is instant-on and instant-off -- `apply_walk`
## writes `velocity.x` outright -- and every jump the player has ever made was
## aimed by that. Ice replaces the write with a blend, so speed arrives late and
## leaves late. **Nothing pushes you anywhere you did not ask to go; you simply
## arrive after you stopped asking.**
##
## ### The fairness rules
##
## Same shape `WindZone`, `ConveyorBelt`, `DarkRoom` and `RisingTide` are held
## to:
##
##   1. **You always stop.** `grip` is greater than zero, so speed decays to
##      nothing and the stopping distance is finite and small -- about a tile
##      and a half at walk speed. A grip of zero is a floor you can never stand
##      still on, which is not ice, it is a conveyor with no direction.
##   2. **It never reverses you and never adds speed.** Ice can only delay what
##      the player asked for. A slide that carried you past your own top speed
##      would be a push, and the two forces that push already exist.
##   3. **An ice run ends before a hole does.** Every ice run in the stage stops
##      at least `STOP_MARGIN_CELLS` of plain deck before a gap, so the player
##      always has grip under them when they take off and when they land.
##      `tests/test_cold_store.gd` checks it against the stopping distance
##      computed from the tuning rather than against the level looking right.
##
## Rule 3 is the one that matters and it is the lesson stage 5 paid for: a force
## that reaches a jump can make authored gaps uncrossable, and no amount of
## retuning fixes it. Ice does not reach the jump -- it is grounded only -- but
## it does reach the **take-off**, which is close enough to need the same care.
class_name IceFloor
extends Area2D

## How much of the player's asked-for speed arrives each frame, 0..1.
##
## 1.0 is ordinary floor. At 0.06 the player reaches full speed in about
## seventeen frames and slides about a tile and a half after letting go, which
## is long enough to feel and short enough to plan around.
const DEFAULT_GRIP := 0.06

@export var grip: float = DEFAULT_GRIP
@export var width_tiles: float = 6.0
## How far above the deck surface the ice looks for a player, in tiles. Same
## reasoning as `ConveyorBelt.height_tiles`: tall enough to hold a standing
## player's origin plus the slack `move_and_slide` leaves, well under a jump.
@export var height_tiles: float = 2.0

const SHEET := Color(0.72, 0.88, 0.96)
const SHEEN := Color(0.94, 0.99, 1.0)
const CRACK := Color(0.48, 0.66, 0.78)

var _tuning: PlayerTuning
var _player: Player = null


## How far a player sliding at walk speed travels after letting go, in NES px.
##
## The sum of a geometric decay: each frame keeps `1 - grip` of the last frame's
## speed, so the total is `v / grip`. Static and pure so the level tests can ask
## it without building a room.
static func stopping_distance_nes(walk_speed_pf: float, at_grip: float) -> float:
	return walk_speed_pf / maxf(at_grip, 0.0001)


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tile := _tuning.tile_size()
	rect.size = Vector2(width_tiles, height_tiles) * tile
	shape.shape = rect
	# Anchored at the run's left end on the deck surface, so the box sits above
	# the deck and reaches up rather than being centred on the floor line.
	shape.position = Vector2(rect.size.x * 0.5, -rect.size.y * 0.5)
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = -5
	queue_redraw()


func has_skater() -> bool:
	return _player != null and is_instance_valid(_player)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


## Written every frame and cleared every frame by the player -- the contract
## `WindZone` and `ConveyorBelt` use, so a sheet that is freed or left behind by
## a room change simply stops writing and grip returns on the next frame.
##
## Written whether or not the player is on the floor. The player applies it only
## while grounded; leaving that decision there rather than here means an ice
## sheet under an overhang does not have to reason about who is standing on what.
func _physics_process(_delta: float) -> void:
	if has_skater():
		_player.ground_grip = grip


func _draw() -> void:
	var tile := _tuning.tile_size()
	var width := width_tiles * tile
	var depth := tile * 0.36
	draw_rect(Rect2(Vector2(0.0, -depth), Vector2(width, depth)), SHEET)
	# A bright lip along the top, so the sheet reads as a surface with a shine
	# rather than a pale rectangle painted on the deck.
	draw_rect(Rect2(Vector2(0.0, -depth), Vector2(width, depth * 0.3)), SHEEN)
	# Cracks, spaced by position rather than by time: the sheet is not animated,
	# because a floor that shimmers reads as a hazard and this one is not.
	var pitch := tile * 1.4
	var at := pitch * 0.5
	while at < width:
		draw_line(Vector2(at, -depth * 0.9), Vector2(at + tile * 0.3, -depth * 0.1),
			CRACK, 2.0)
		at += pitch
