## The intro: four cards before the title, skippable on any press.
##
## **It exists to answer one question the game otherwise never answers**, which
## is why the coast is drowned. Eight stages are set in it and not one of them
## says so; the fiction has lived entirely in docstrings since M0, where no
## player will ever read it.
##
## Four cards, because four is what it takes to say it and a fifth would be a
## story. docs/PLAN.md's scope is explicit -- "no branching narrative" -- and
## this is the smallest thing that is not nothing.
##
## **Skippable from the first frame.** An intro that has to be sat through is an
## intro that is resented on the second run, and this one will be seen by the
## same person many times.
class_name IntroScreen
extends CanvasLayer

signal finished()

const BACKDROP := Color(0.04, 0.05, 0.09, 1.0)
const TEXT := Color(0.88, 0.91, 0.98)
const ACCENT := Color(0.98, 0.86, 0.35)

## Frames a card holds, and frames it takes to fade between them.
const CARD_FRAMES := 190
const FADE_FRAMES := 26

const CARDS := [
	["THE COAST", "A boardwalk, a substation, a shipbreaking yard.\nEight places that were somebody's work."],
	["THE WALL", "Bulwark built it to hold the sea out.\nIt worked."],
	["THE WATER", "It had to go somewhere.\nIt went behind the wall."],
	["NOW", "Eight machines run the wall.\nOne of them is standing in your way."],
]

var _frames := 0
var _card := 0
var _title: Label
var _body: Label
var _done := false


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_show(0)


func card() -> int:
	return _card


func is_finished() -> bool:
	return _done


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	# Fade in over the first frames of a card and out over the last, so the
	# cards read as one sequence rather than four screens.
	var alpha := 1.0
	if _frames < FADE_FRAMES:
		alpha = float(_frames) / float(FADE_FRAMES)
	elif _frames > CARD_FRAMES - FADE_FRAMES:
		alpha = float(CARD_FRAMES - _frames) / float(FADE_FRAMES)
	_set_alpha(clampf(alpha, 0.0, 1.0))
	if _frames < CARD_FRAMES:
		return
	if _card + 1 >= CARDS.size():
		skip()
		return
	_show(_card + 1)


## Straight to the title. Called by a press and by the last card running out, so
## there is one way out rather than two.
func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	var router := get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"shoot") \
			or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		skip()


func _show(index: int) -> void:
	_card = index
	_frames = 0
	_title.text = String(CARDS[index][0])
	_body.text = String(CARDS[index][1])
	_set_alpha(0.0)


func _set_alpha(alpha: float) -> void:
	_title.modulate.a = alpha
	_body.modulate.a = alpha


func _build() -> void:
	var panel := ColorRect.new()
	panel.name = "Backdrop"
	panel.color = BACKDROP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_title = Label.new()
	_title.name = "Card"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override(&"font_color", ACCENT)
	_title.add_theme_font_size_override(&"font_size", 64)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = 400.0
	panel.add_child(_title)

	_body = Label.new()
	_body.name = "Body"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_color_override(&"font_color", TEXT)
	_body.add_theme_font_size_override(&"font_size", 30)
	_body.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_body.position.y = 510.0
	panel.add_child(_body)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "any key to skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", Color(0.40, 0.44, 0.54))
	hint.add_theme_font_size_override(&"font_size", 22)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.position.y = 990.0
	panel.add_child(hint)
