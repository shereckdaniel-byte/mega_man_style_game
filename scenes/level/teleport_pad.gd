## A pad on the deck that takes the player somewhere else.
##
## **The fortress's third way between rooms**, after the door and the ladder,
## and the only one that is not a journey. `Stage.teleport_player` does the
## moving; this is the thing on the floor that asks for it.
##
## ### It reports rather than acts
##
## The pad does not know where it goes. It emits `used` with its own index and
## the stage decides -- which is what lets Switchgear's eight pads be eight
## copies of one node whose destinations change as bosses fall, rather than
## eight pads each holding a NodePath that has to be rewritten when the room
## table moves. It is the same split `Door` uses, and the reason is the same:
## the geometry belongs to the level, not to the trigger standing on it.
##
## ### Standing on a pad is not using it
##
## **It fires on a press of up, not on contact**, and that is the rule that makes
## Switchgear's hub a room about choosing. Eight plates in one room means walking
## across most of them to reach the one you want, and a pad that fired on overlap
## would take the first one you brushed -- so the room would be asking a question
## and then answering it for you.
##
## The first version did fire on contact, and the room was authored around it:
## the pads had to be spaced so that a stride could not touch two, which put them
## three cells apart and left no room in a 28-cell hub for the ninth plate. The
## test that caught it (`test_the_pads_are_far_enough_apart_to_choose_between`)
## was really saying that contact was the wrong trigger.
##
## Up is the convention every game with a doorway uses, and the pad shows it: the
## column of light brightens while the player is standing in it.
##
## A pad still **arms only once it is empty**, because the player arrives on the
## return pad of every arena and could easily still be holding up from the press
## that sent them. `disarm_until_empty` is called by the stage on the pad a
## teleport is about to deliver to -- there is no way for the pad to know which
## one it is.
class_name TeleportPad
extends Area2D

## The player stepped on an armed pad. The stage decides what that means.
signal used(pad: TeleportPad)

## Size in tiles, anchored at the pad's own position, which sits on the deck
## surface at the pad's centre.
const SIZE_TILES := Vector2(1.5, 0.5)

const RING := Color(0.52, 0.86, 0.96)
const RING_DIM := Color(0.30, 0.36, 0.44)
const GLOW := Color(0.70, 0.94, 1.0)
## Frames of the idle pulse, so a live pad reads as live standing still.
const PULSE_FRAMES := 72

## Which pad this is, in the stage's own numbering.
@export var pad_index: int = 0
## A pad that is switched off: it draws dark and does not fire. Switchgear's
## exit is one of these until all eight are down.
@export var live: bool = true

var _armed := true
var _frames := 0
var _tile := 72.0
var _inside := false


func _ready() -> void:
	collision_layer = Layers.bit(Layers.TRIGGER)
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE_TILES * _tile
	shape.shape = rect
	# The pad's origin is the middle of its top edge, on the deck surface, so a
	# stage places it at a cell and a deck row like everything else in the kit.
	shape.position.y = rect.size.y * 0.5
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Called by the stage for the pad the player is about to land on. A pad that
## fired the moment they arrived would send them back before they had seen the
## room.
func disarm_until_empty() -> void:
	_armed = false


func is_armed() -> bool:
	return _armed


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_inside = true


func is_occupied() -> bool:
	return _inside


## Fires the pad as if the player had asked for it.
##
## Public because the press is read here and there is no input device in a
## headless test -- the alternative is a test that reaches into `Input`, which
## makes the suite depend on the input map as well as on the pad. Refuses for
## every reason the press would.
func use_now() -> bool:
	if not _inside or not live or not _armed:
		return false
	_armed = false
	Sfx.play(&"teleport_pad")
	used.emit(self)
	return true


func _on_body_exited(body: Node2D) -> void:
	if not (body is Player):
		return
	_inside = false
	_armed = true


func _physics_process(_delta: float) -> void:
	_frames += 1
	queue_redraw()
	if _inside and live and _armed and _wants_up():
		use_now()


## The press. Split out so a test can drive the pad without an input device and
## so the binding lives in one place rather than inside the frame loop.
func _wants_up() -> bool:
	return Input.is_action_pressed(&"move_up")


func _draw() -> void:
	var width := SIZE_TILES.x * _tile
	var height := SIZE_TILES.y * _tile
	var base := RING if live else RING_DIM
	# The plate.
	draw_rect(Rect2(Vector2(-width * 0.5, 0.0), Vector2(width, height)),
		Color(base, 0.35))
	draw_rect(Rect2(Vector2(-width * 0.5, 0.0), Vector2(width, height * 0.22)),
		Color(base, 0.85))
	if not live:
		return
	# A column of light, breathing. It is the only vertical thing in a room of
	# horizontal ones, which is what makes a pad findable at a glance.
	var t := float(_frames % PULSE_FRAMES) / float(PULSE_FRAMES)
	var lift := 1.0 - absf(t * 2.0 - 1.0)
	# Brighter and taller with the player in it, which is the only thing on
	# screen that says "up does something here".
	if _inside:
		lift = 1.0
	var tall := _tile * (1.6 + 0.5 * lift) * (1.35 if _inside else 1.0)
	draw_rect(Rect2(Vector2(-width * 0.16, -tall), Vector2(width * 0.32, tall)),
		Color(GLOW, 0.10 + 0.14 * lift))
	draw_rect(Rect2(Vector2(-width * 0.05, -tall), Vector2(width * 0.10, tall)),
		Color(GLOW, 0.22 + 0.24 * lift))
