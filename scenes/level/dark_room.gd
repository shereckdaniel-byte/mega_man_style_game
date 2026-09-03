## Substation's gimmick: the lights are out and the switchgear arcs.
##
## The room is dark, and every few seconds an arc flash across the busbars lights
## the whole of it for about half a second. You move on the flash and coast on
## what you remembered.
##
## **The design constraint is the same one RisingTide has, and it is the reason
## dark rooms are usually bad.** A gimmick that removes information can always be
## made unfair, and the unfair version is easier to build than the fair one: turn
## the lights off, put a pit in the dark, and the player dies to something they
## were never shown. Three rules keep this the other kind:
##
##   * **It is never fully black.** `MAX_DARKNESS` caps the overlay well short of
##     opaque, so the floor line, the player and anything moving stay readable as
##     silhouettes at all times. Dark enough to lose detail, never dark enough to
##     lose the ground.
##   * **The flash is on a fixed period**, not a random one. A rhythm can be
##     learned and moved to; a coin flip can only be waited out, and waiting is
##     not play.
##   * **It is purely visual.** No collision, no damage, no input change. Nothing
##     here can kill you, so a death in a dark room is always something else's,
##     and the darkness cannot be the thing that makes a room lethal.
##
## Which leaves the gimmick doing what a gimmick should: changing how you read a
## room you could otherwise walk through without looking.
##
## A CanvasLayer rather than a Node2D, because the darkness belongs to the
## viewport and not to the world: a rectangle in world space has to be sized and
## followed to the camera, and the frame it lags by is a bright band down the
## side of the screen.
class_name DarkRoom
extends CanvasLayer

## Emitted on the frame a flash reaches full brightness. For tests, and for
## anything that later wants to sync to the rhythm.
signal flashed()

## Between the world and the HUD. The player must be dimmed with the level --
## the whole point is not being able to see them clearly -- and the energy bar
## must not be, because a HUD you cannot read is a interface bug wearing a
## gimmick's clothes.
const LAYER := 5

## The darkest the overlay is ever allowed to get.
##
## Not a taste setting: this is the promise that the room stays playable. At 0.82
## the deck still reads as a line and a moving enemy still reads as a shape --
## checked against the tileset rather than picked, because the tileset is dark to
## begin with and 0.9 over it was genuinely opaque. `tests/test_dark_room.gd`
## asserts nothing ever exceeds it, so a later "make it spookier" cannot quietly
## cross into unfair.
const MAX_DARKNESS := 0.82

## The overlay's colour. Deep blue rather than black: a neutral black flattens
## everything behind it to grey, and the stage's palette is cold to begin with.
const GLOOM := Color(0.03, 0.05, 0.11)

@export var dark_alpha := 0.78
## How bright it gets at the peak of a flash. Not zero -- the flash is an arc,
## not the lights coming back on, and a hard cut to full colour reads as the
## overlay being switched off rather than as something happening in the room.
@export var flash_alpha := 0.06

## The rhythm, in physics frames. 150 is 2.5 seconds of dark; 34 is a bit over
## half a second of light, which is enough to cross a room's width at walk speed
## if you start moving on it.
@export var period_frames := 150
@export var flash_frames := 34
## Frames the flash takes to arrive and to fade. The arrival is fast because an
## arc is fast; the fade is slower so the room dims back rather than snapping.
@export var flash_rise_frames := 3
@export var flash_fall_frames := 16

## Frames the overlay takes to appear or clear when a room changes. A hard cut at
## a doorway looks like a rendering fault; this reads as walking into the dark.
@export var transition_frames := 24

var _active := false
var _frames := 0
## 0 outside a dark room, 1 fully inside. Ramps across `transition_frames`.
var _presence := 0.0
var _rect: ColorRect


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.name = "Gloom"
	_rect.color = Color(GLOOM.r, GLOOM.g, GLOOM.b, 0.0)
	# Full-viewport and never in the way of a click or a key.
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


## Called by the stage when the player enters or leaves a dark room.
##
## Entering restarts the cycle, which puts the flash at the moment of arrival:
## the room lights up as you walk in, shows you its shape, and then goes dark.
##
## That order is deliberate and it is the kind one. The alternative -- picking up
## wherever the previous room's rhythm happened to be -- means walking into the
## dark half the time with nothing yet seen, and the player has no way to tell
## the two cases apart. Being shown the room first and losing it is a memory
## test; being dropped into the dark is a guess.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	if on:
		_frames = 0


func is_active() -> bool:
	return _active


## Physics frames since the room was entered. `cycle_frame()` is this modulo the
## period; this one keeps counting, which is what a caller comparing successive
## flashes needs.
func elapsed_frames() -> int:
	return _frames


## The overlay's current alpha. 0 is clear.
func darkness() -> float:
	return _rect.color.a if _rect != null else 0.0


## Where the cycle is, in frames since the room was entered.
func cycle_frame() -> int:
	return _frames % maxi(period_frames, 1)


## True while a flash is lighting the room.
func is_flashing() -> bool:
	return _active and cycle_frame() < flash_frames


func _physics_process(_delta: float) -> void:
	var was_flashing := is_flashing()
	if _active:
		_frames += 1
	var step := 1.0 / float(maxi(transition_frames, 1))
	_presence = clampf(_presence + (step if _active else -step), 0.0, 1.0)
	_apply()
	if is_flashing() and not was_flashing:
		flashed.emit()


func _apply() -> void:
	if _rect == null:
		return
	# The gimmick's own alpha, then faded by how far into the room we are.
	var alpha := _cycle_alpha() * _presence
	_rect.color = Color(GLOOM.r, GLOOM.g, GLOOM.b, minf(alpha, MAX_DARKNESS))


## Alpha for this point in the cycle, ignoring the room transition.
##
## The flash sits at the *start* of the period rather than the end, so
## `cycle_frame() < flash_frames` is the whole test for "is it lit" and a reader
## does not have to do modular arithmetic to answer it.
func _cycle_alpha() -> float:
	if not _active and _presence <= 0.0:
		return 0.0
	var frame := cycle_frame()
	if frame >= flash_frames:
		return dark_alpha
	if frame < flash_rise_frames:
		# Arriving: dark -> bright, fast.
		var t := float(frame) / float(maxi(flash_rise_frames, 1))
		return lerpf(dark_alpha, flash_alpha, t)
	var hold := flash_frames - flash_fall_frames
	if frame < hold:
		return flash_alpha
	# Fading back down.
	var t := float(frame - hold) / float(maxi(flash_fall_frames, 1))
	return lerpf(flash_alpha, dark_alpha, t)
