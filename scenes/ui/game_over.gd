## The end of a run: out of lives.
##
## Exists because `Player.game_over` was being emitted into nothing. The player
## spent their last life, the Dead state finished its burst, the signal fired,
## and then the game simply stopped -- character invisible, no screen, no
## respawn, no way forward but closing the window. Not a missing feature so much
## as a disconnected wire, and one nobody meets until they actually run out,
## which a bot with 99 lives never does.
##
## Deliberately plainer than the weapon-get screen. This is the one moment the
## game has nothing to celebrate, and dressing it up reads as gloating.
class_name GameOver
extends CanvasLayer

signal finished()

## Frames before input can dismiss it. Long enough that the button held during
## the death that caused it does not skip the screen entirely.
const MIN_FRAMES := 60
## Frames after which it continues by itself.
const AUTO_FRAMES := 420
const FADE_FRAMES := 30

const BACKDROP := Color(0.02, 0.02, 0.03, 0.96)
const TITLE_COLOUR := Color(0.92, 0.94, 1.0)
const HINT_COLOUR := Color(0.50, 0.55, 0.66)

var _frames := 0
var _dismissed := false
var _panel: ColorRect
var _hint: Label


static func show_over(parent: Node) -> GameOver:
	var screen := GameOver.new()
	screen.name = "GameOver"
	parent.add_child(screen)
	screen.setup()
	return screen


func _ready() -> void:
	layer = 60
	# Runs while the tree is paused, so a game over during a pause still ends.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup() -> void:
	_panel = ColorRect.new()
	_panel.color = BACKDROP
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.modulate.a = 0.0
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 30)
	_panel.add_child(box)

	_label(box, "GAME OVER", TITLE_COLOUR, 72)
	_hint = _label(box, "press jump to try again", HINT_COLOUR, 28)
	_hint.visible = false


func is_finished() -> bool:
	return _dismissed


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
