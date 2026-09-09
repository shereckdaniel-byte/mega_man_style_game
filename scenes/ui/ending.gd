## The ending and the credits, in one screen and one scroll.
##
## **The only screen in the game that nothing follows.** Everything else hands
## the player somewhere: a stage hands them to the select, the select to a
## stage, a game over back to the start of one. This hands them to the title,
## and only after they ask -- a run that took four fortress stages should not be
## dismissed by a stray button press on the frame it ends.
##
## ### Why the ending and the credits are one screen
##
## Because they are one moment. Splitting them means an ending screen that waits
## for a press and then a credits screen that scrolls, and the press in between
## is the player being asked to acknowledge the end of the game before being
## allowed to see who made it. The scroll starts under the last line of the
## ending and runs on.
##
## The text is deliberately short. Nobody has written a story for this game --
## docs/PLAN.md's scope says "no branching narrative" and means it -- so what is
## here is the four facts the game itself establishes: the coast is drowned, the
## wall did it, the eight ran it, and they are down.
class_name EndingScreen
extends CanvasLayer

## The player asked to leave. The title comes next.
signal finished()

const BACKDROP := Color(0.04, 0.05, 0.09, 1.0)
const TEXT := Color(0.88, 0.91, 0.98)
const DIM := Color(0.46, 0.50, 0.60)
const ACCENT := Color(0.98, 0.86, 0.35)

## Frames the ending text holds before the credits begin to move. Long enough to
## read twice.
const HOLD_FRAMES := 260
## Pixels a frame. Slow: credits that outrun reading are credits nobody reads.
const SCROLL_SPEED := 0.9
## Frames after the last line clears the top before the prompt appears.
const TAIL_FRAMES := 90

const EPILOGUE := [
	"THE WALL IS OPEN.",
	"",
	"The sea goes back where it was taken from,",
	"and the coast comes up out of it —",
	"a boardwalk, a substation, a shipbreaking yard,",
	"eight places that were somebody's work.",
	"",
	"Bulwark built a wall to hold the water out",
	"and drowned everything behind it holding it.",
	"",
	"The eight are down. The lights are on.",
	"",
	"Somebody will have to rebuild the pier.",
]

const CREDITS := [
	"", "", "",
	"SEAWALL",
	"",
	"an original action-platformer",
	"in the style of Mega Man 3",
	"", "",
	"DESIGN AND CODE",
	"Claude, with Daniel Shereck",
	"", "",
	"ENGINE",
	"Godot 4.7",
	"", "",
	"CHARACTER AND STAGE ART",
	"AutoSprite and PixelLab",
	"", "",
	"MUSIC AND SOUND",
	"synthesised in-engine",
	"two pulses, a triangle and some noise",
	"tools/synth.gd",
	"", "",
	"THE EIGHT",
	"Tide · Arc · Rust · Prism",
	"Gale · Cinder · Frost · Quarry",
	"", "",
	"AND",
	"Ward, who never lost",
	"Bulwark, who did",
	"", "", "",
	"787 tests, and every one of them earned",
	"", "", "",
	"THANK YOU FOR PLAYING",
]

var _frames := 0
var _scroll: Control
var _prompt: Label
var _done := false


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Music.play(&"jingle_ending")


func is_finished() -> bool:
	return _done


## How far the credits have scrolled, in pixels. For the tests.
func scrolled() -> float:
	return maxf(float(_frames - HOLD_FRAMES), 0.0) * SCROLL_SPEED


func _process(_delta: float) -> void:
	_frames += 1
	if _scroll != null:
		_scroll.position.y = _start_y() - scrolled()
	if _prompt != null and not _prompt.visible and _is_over():
		_prompt.visible = true


## True once the last credit line has left the top of the screen.
func _is_over() -> bool:
	return scrolled() > _scroll_height() + float(TAIL_FRAMES)


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"jump") or event.is_action_pressed(&"shoot")):
		return
	get_viewport().set_input_as_handled()
	# **The first press skips to the end of the scroll; the second leaves.**
	# One press doing both would end the game on a button somebody was still
	# holding from the last shot of the last fight.
	if not _is_over():
		_frames = HOLD_FRAMES + int((_scroll_height() + float(TAIL_FRAMES))
			/ SCROLL_SPEED) + 1
		return
	_done = true
	Sfx.play(&"confirm")
	finished.emit()
	var router := get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto_title()


# --- Layout ------------------------------------------------------------------------

func _start_y() -> float:
	return 1080.0


func _scroll_height() -> float:
	return float(CREDITS.size()) * 46.0 + 1080.0


func _build() -> void:
	var panel := ColorRect.new()
	panel.name = "Backdrop"
	panel.color = BACKDROP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# The epilogue sits still at the top and stays there: it is the thing the
	# player earned, and it should not scroll away while they are reading it.
	var epilogue := VBoxContainer.new()
	epilogue.name = "Epilogue"
	epilogue.set_anchors_preset(Control.PRESET_TOP_WIDE)
	epilogue.position.y = 90.0
	epilogue.add_theme_constant_override(&"separation", 6)
	panel.add_child(epilogue)
	for i in EPILOGUE.size():
		epilogue.add_child(_line(EPILOGUE[i], 30, ACCENT if i == 0 else TEXT))

	_scroll = VBoxContainer.new()
	_scroll.name = "Credits"
	_scroll.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_scroll.position.y = _start_y()
	_scroll.add_theme_constant_override(&"separation", 10)
	panel.add_child(_scroll)
	for line in CREDITS:
		var big := line == line.to_upper() and not line.strip_edges().is_empty()
		_scroll.add_child(_line(line, 40 if big else 28, ACCENT if big else DIM))

	_prompt = _line("PRESS FIRE", 30, TEXT)
	_prompt.name = "Prompt"
	_prompt.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_prompt.position.y = 980.0
	_prompt.visible = false
	panel.add_child(_prompt)


func _line(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_font_size_override(&"font_size", size)
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	return label
