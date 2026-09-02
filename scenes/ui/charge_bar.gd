## The charge meter: a horizontal strip that fills as the fire button is held.
##
## The original had no such thing -- MM4 onward showed the charge by flashing the
## character and by sound alone. A bar was asked for, so there is one, but the
## flash is kept as well and is still doing most of the work: the player is
## looking at the character during a fight, not at the corner of the screen.
##
## Segmented rather than smooth, to match EnergyBar, and marked at the point the
## charge becomes worth releasing -- a continuous fill tells you how long you
## have held, which is not the question. The question is "is it worth letting
## go yet", and only the threshold answers that.
class_name ChargeBar
extends Control

## Bar geometry in NES pixels, scaled by world_scale like the rest of the HUD.
const SEGMENT_NES := Vector2(3.0, 6.0)
const SEGMENT_GAP_NES := 1.0
const BORDER_NES := 1.0
const SEGMENTS := 14

const EMPTY_COLOUR := Color(0.10, 0.12, 0.20, 0.85)
const BORDER_COLOUR := Color(0.92, 0.96, 1.0)
## Below the first stage: filling, not yet useful.
const BUILDING_COLOUR := Color(0.45, 0.55, 0.70)
const MID_COLOUR := Color(0.40, 0.78, 1.0)
const FULL_COLOUR := Color(1.0, 1.0, 0.92)

var _fraction := 0.0
var _level := 0
var _mid_at := 0.5
var _scale := 4.5
var _blink := 0


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_scale = autoload.player.world_scale
	custom_minimum_size = _bar_size()
	visible = false


## Where the first charged stage sits along the bar, so the mark is drawn in the
## right place for whatever weapon is equipped rather than at a fixed halfway.
func set_threshold(fraction: float) -> void:
	_mid_at = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func set_charge(fraction: float, level: int) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	_level = level
	# Hidden at rest. A permanently visible empty bar is one more thing on
	# screen that is telling the player nothing.
	visible = _fraction > 0.0
	queue_redraw()


func fraction() -> float:
	return _fraction


func level() -> int:
	return _level


func _physics_process(_delta: float) -> void:
	if _level >= 2:
		_blink += 1
		queue_redraw()
	elif _blink != 0:
		_blink = 0
		queue_redraw()


func _bar_size() -> Vector2:
	var segment := SEGMENT_NES * _scale
	var gap := SEGMENT_GAP_NES * _scale
	var border := BORDER_NES * _scale
	return Vector2(
		float(SEGMENTS) * (segment.x + gap) - gap + border * 2.0,
		segment.y + border * 2.0)


func _draw() -> void:
	var segment := SEGMENT_NES * _scale
	var gap := SEGMENT_GAP_NES * _scale
	var border := BORDER_NES * _scale
	var size := _bar_size()

	draw_rect(Rect2(Vector2.ZERO, size), EMPTY_COLOUR)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOUR, false, border)

	var fill := BUILDING_COLOUR
	if _level >= 2:
		# Full charge blinks, which is the part read out of the corner of an eye.
		fill = FULL_COLOUR if (_blink / 4) % 2 == 0 else MID_COLOUR
	elif _level == 1:
		fill = MID_COLOUR

	var lit := int(round(_fraction * float(SEGMENTS)))
	for i in SEGMENTS:
		if i >= lit:
			continue
		var at := Vector2(border + float(i) * (segment.x + gap), border)
		draw_rect(Rect2(at, segment), fill)

	# The threshold mark: left of it the charge is not worth releasing.
	var mark_x := border + _mid_at * (size.x - border * 2.0)
	draw_line(Vector2(mark_x, 0.0), Vector2(mark_x, size.y), BORDER_COLOUR, maxf(border, 1.0))
