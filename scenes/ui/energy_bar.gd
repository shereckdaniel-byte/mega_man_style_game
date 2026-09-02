## The segmented energy bar.
##
## 28 segments because the player and every boss have 28 HP, so one segment is
## one HP and there is no scaling maths anywhere (ARCHITECTURE section 5.3). A
## bar that had to map 100 HP onto 28 ticks would round, and a rounded bar lies
## about whether the next hit kills you.
##
## Drains and refills **one tick at a time** rather than jumping to the new
## value. That is not decoration: the refill pause is a real beat in the
## original's pacing -- picking up a large energy capsule stops play for about a
## second, and an E-tank for nearly three.
class_name EnergyBar
extends Control

## Physics frames per tick. Draining and filling deliberately run at different
## rates: a hit should register immediately, while a refill is a *pause* in play
## -- an E-tank in the original stops the game for the better part of three
## seconds, and that beat is part of the pacing.
##
## The drain rate also has to empty a full bar inside the death sequence
## (72 frames), or the bar is still visibly draining when the player respawns.
const DRAIN_FRAMES_PER_TICK := 2
const FILL_FRAMES_PER_TICK := 4

## Bar geometry in NES pixels, scaled by world_scale so the HUD matches the art.
const SEGMENT_NES := Vector2(8.0, 2.0)
const SEGMENT_GAP_NES := 1.0
const BORDER_NES := 1.0

@export var ticks: int = Health.BAR_TICKS
@export var fill_colour := Color(0.60, 0.85, 1.0)
@export var empty_colour := Color(0.10, 0.12, 0.20, 0.85)
@export var border_colour := Color(0.92, 0.96, 1.0)

var _target := 0
var _shown := 0
var _frames := 0
var _scale := 4.5


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_scale = autoload.player.world_scale
	custom_minimum_size = _bar_size()
	_target = ticks
	_shown = ticks
	queue_redraw()


## Hooks the bar to a Health and seeds it with the current value.
func track(health: Health) -> void:
	ticks = health.max_hp
	_target = health.current
	_shown = health.current
	health.changed.connect(_on_health_changed)
	custom_minimum_size = _bar_size()
	queue_redraw()


func set_value(value: int) -> void:
	_target = clampi(value, 0, ticks)


## Jumps straight to a value with no animation, for a respawn -- the tick-by-tick
## refill is for pickups, not for the bar reappearing after a death.
func snap_to(value: int) -> void:
	_target = clampi(value, 0, ticks)
	_shown = _target
	queue_redraw()


func is_settled() -> bool:
	return _shown == _target


func shown_value() -> int:
	return _shown


func _physics_process(_delta: float) -> void:
	if _shown == _target:
		return
	_frames += 1
	var rate := DRAIN_FRAMES_PER_TICK if _target < _shown else FILL_FRAMES_PER_TICK
	if _frames < rate:
		return
	_frames = 0
	_shown += signi(_target - _shown)
	queue_redraw()


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum != ticks:
		ticks = maximum
		custom_minimum_size = _bar_size()
	set_value(current)


func _bar_size() -> Vector2:
	var segment := SEGMENT_NES * _scale
	var gap := SEGMENT_GAP_NES * _scale
	var border := BORDER_NES * _scale
	return Vector2(
		segment.x + border * 2.0,
		float(ticks) * (segment.y + gap) - gap + border * 2.0)


func _draw() -> void:
	var segment := SEGMENT_NES * _scale
	var gap := SEGMENT_GAP_NES * _scale
	var border := BORDER_NES * _scale
	var size := _bar_size()

	draw_rect(Rect2(Vector2.ZERO, size), empty_colour)
	draw_rect(Rect2(Vector2.ZERO, size), border_colour, false, border)

	# Drawn top-down but filled bottom-up, the way the original's bar empties
	# from the top.
	for i in ticks:
		var from_bottom := ticks - 1 - i
		if from_bottom >= _shown:
			continue
		var at := Vector2(border, border + float(i) * (segment.y + gap))
		draw_rect(Rect2(at, segment), fill_colour)
