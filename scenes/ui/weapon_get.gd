## The screen after a boss dies: "you got the weapon".
##
## A beat, not a menu. The original stops play entirely here -- the stage is
## still standing behind it, nothing is scrolling, and the only thing to do is
## read the name and press a button. That pause is doing work: it is where the
## player learns the weapon exists at all, and it is the reward for the fight.
##
## Dismissable early but not instantly. `MIN_FRAMES` exists because the button
## the player was holding to shoot the boss is usually still held on the frame
## it dies, and a screen that can be skipped on frame 1 is a screen the player
## never sees.
class_name WeaponGet
extends CanvasLayer

signal finished()

## Frames before input can dismiss it.
const MIN_FRAMES := 45
## Frames after which it dismisses itself, for a player who presses nothing.
const AUTO_FRAMES := 300
## Frames the panel takes to fade in.
const FADE_FRAMES := 18

const BACKDROP := Color(0.02, 0.03, 0.06, 0.92)
const TITLE_COLOUR := Color(0.72, 0.86, 1.0)
const NAME_COLOUR := Color(1.0, 0.88, 0.42)
const HINT_COLOUR := Color(0.55, 0.62, 0.75)

var _frames := 0
var _dismissed := false
var _panel: ColorRect
var _title: Label
var _name: Label
var _hint: Label


## Builds and shows the screen. `weapon_name` is the display name, not the id --
## this is the one place the player sees a weapon written out.
static func show_for(parent: Node, weapon_name: String, boss_name: String) -> WeaponGet:
	var screen := WeaponGet.new()
	screen.name = "WeaponGet"
	parent.add_child(screen)
	screen.setup(weapon_name, boss_name)
	return screen


func _ready() -> void:
	layer = 50
	# Runs while the stage is paused, so the fight really does stop.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(weapon_name: String, boss_name: String) -> void:
	_panel = ColorRect.new()
	_panel.color = BACKDROP
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.modulate.a = 0.0
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 24)
	_panel.add_child(box)

	_title = _label(box, "%s DEFEATED" % boss_name.to_upper(), TITLE_COLOUR, 40)
	_name = _label(box, "YOU GOT  %s" % weapon_name.to_upper(), NAME_COLOUR, 64)
	_hint = _label(box, "press jump", HINT_COLOUR, 28)
	_hint.visible = false


func is_finished() -> bool:
	return _dismissed


## Dismisses it now, whatever the frame count. For a test, and for the stage if
## it ever needs to take the screen away itself.
func dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	finished.emit()
	queue_free()


func _process(_delta: float) -> void:
	_frames += 1
	if _panel != null:
		_panel.modulate.a = minf(float(_frames) / float(FADE_FRAMES), 1.0)
	if _frames < MIN_FRAMES:
		return
	if _hint != null:
		_hint.visible = true
	if _frames >= AUTO_FRAMES:
		dismiss()
		return
	if Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"shoot"):
		dismiss()


func _label(parent: Node, text: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_font_size_override(&"font_size", size)
	parent.add_child(label)
	return label
