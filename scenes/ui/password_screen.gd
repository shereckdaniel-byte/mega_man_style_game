## The password screen: read one off, or type one in.
##
## Both directions on one screen, because they are the same grid. The player
## arrives here from the stage select either to write down where they are or to
## get back to where they were, and a screen that did only one of those would
## need a second screen that looked identical.
##
## ### It shows the current password on arrival
##
## Opened, it is already displaying the run's own password with the cursor on
## `A1`. That is the "write this down" half and it costs nothing: the grid has
## to be drawn anyway, and the alternative -- an empty grid with the current one
## somewhere else -- means the player has to trust that two drawings of the same
## thing agree.
##
## ### A refused password says so and keeps what you typed
##
## `Password.decode` returns nothing for a grid it does not trust, and the
## screen reports that rather than clearing. Wiping the grid on a wrong answer
## is the behaviour that makes people give up: twenty-five dots is a lot to
## re-enter when the mistake was one of them, and the checksum is specifically
## good at catching *one* of them.
class_name PasswordScreen
extends Control

## Emitted when the player leaves, with whether a password was actually loaded.
signal finished(loaded: bool)

const BACKDROP := Color(0.05, 0.06, 0.10, 1.0)
const GRID_LINE := Color(0.28, 0.32, 0.42)
## The classic two colours. Which one a cell uses is decided by position, not by
## meaning: MM3's grid is red and blue and this is that look, one bit per cell,
## exactly as docs/ARCHITECTURE.md section 8 specifies.
const DOT_RED := Color(0.92, 0.30, 0.32)
const DOT_BLUE := Color(0.38, 0.62, 0.98)
const CURSOR := Color(0.98, 0.86, 0.35)
const TEXT := Color(0.86, 0.90, 0.98)
const DIM := Color(0.46, 0.50, 0.60)
const BAD := Color(1.0, 0.52, 0.45)
const GOOD := Color(0.45, 0.85, 0.55)

const CELL_SIZE := 96.0
const CELL_GAP := 14.0
## Frames a report line stays up before it fades back to the hint.
const REPORT_FRAMES := 150

var cells: Array[bool] = []
var cursor := Vector2i.ZERO

var _grid: Control
var _status: Label
var _report_left := 0
var _loaded := false


## Opens the screen over `parent`, filled in with the current run's password.
static func open(parent: Node) -> PasswordScreen:
	var screen := PasswordScreen.new()
	parent.add_child(screen)
	return screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above the stage select, and running while the tree behind it is paused --
	# the same arrangement `PauseMenu` uses.
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var state := get_node_or_null(^"/root/GameState")
	cells = Password.encode(state.to_dict()) if state != null else _blank()
	_build()
	_refresh()


## Toggles the cell under the cursor.
func toggle() -> void:
	var index := cursor.y * Password.COLUMNS + cursor.x
	if index < 0 or index >= Password.CELLS:
		return
	cells[index] = not cells[index]
	_refresh()


func move_cursor(delta: Vector2i) -> void:
	cursor = Vector2i(
		clampi(cursor.x + delta.x, 0, Password.COLUMNS - 1),
		clampi(cursor.y + delta.y, 0, Password.ROWS - 1))
	_refresh()


## Reads the grid. True when it was a real password and the run was loaded.
##
## **A refusal leaves the grid alone.** See the class docstring: clearing it is
## what makes people give up on a system whose whole job is surviving a typo.
func submit() -> bool:
	var progress := Password.decode(cells)
	if progress.is_empty():
		_say("WRONG PASSWORD", BAD)
		return false
	var state := get_node_or_null(^"/root/GameState")
	if state == null:
		_say("NO GAME STATE", BAD)
		return false
	state.from_dict(progress)
	_loaded = true
	_say("PASSWORD ACCEPTED", GOOD)
	return true


func loaded() -> bool:
	return _loaded


func close() -> void:
	finished.emit(_loaded)
	queue_free()


## The grid as text, for the console and the tests.
func as_text() -> String:
	return Password.to_text(cells)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_left"):
		move_cursor(Vector2i(-1, 0))
	elif event.is_action_pressed(&"move_right"):
		move_cursor(Vector2i(1, 0))
	elif event.is_action_pressed(&"move_up"):
		move_cursor(Vector2i(0, -1))
	elif event.is_action_pressed(&"move_down"):
		move_cursor(Vector2i(0, 1))
	elif event.is_action_pressed(&"shoot"):
		toggle()
	elif event.is_action_pressed(&"jump"):
		if submit():
			close()
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"melee"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _report_left > 0:
		_report_left -= 1
		if _report_left == 0:
			_refresh()


# --- Layout --------------------------------------------------------------------

func _build() -> void:
	var back := ColorRect.new()
	back.color = BACKDROP
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_heading(column, "PASSWORD", 52, TEXT)

	var centred := HBoxContainer.new()
	centred.alignment = BoxContainer.ALIGNMENT_CENTER
	centred.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(centred)

	_grid = Control.new()
	var span := CELL_SIZE * float(Password.COLUMNS) \
		+ CELL_GAP * float(Password.COLUMNS - 1)
	_grid.custom_minimum_size = Vector2(span, span)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.draw.connect(_draw_grid)
	centred.add_child(_grid)

	_status = _heading(column, "", 26, DIM)
	_heading(column, "SHOOT: MARK    JUMP: ENTER    PAUSE: BACK", 22, DIM)


func _heading(parent: Node, text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _refresh() -> void:
	if _grid != null:
		_grid.queue_redraw()
	if _status != null and _report_left == 0:
		_status.text = Password.cell_name(cursor.y * Password.COLUMNS + cursor.x)
		_status.add_theme_color_override("font_color", DIM)


func _say(message: String, colour: Color) -> void:
	if _status == null:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", colour)
	_report_left = REPORT_FRAMES


func _draw_grid() -> void:
	for row in Password.ROWS:
		for column in Password.COLUMNS:
			var at := Vector2(float(column), float(row)) * (CELL_SIZE + CELL_GAP)
			var box := Rect2(at, Vector2(CELL_SIZE, CELL_SIZE))
			_grid.draw_rect(box, GRID_LINE, false, 3.0)
			var index := row * Password.COLUMNS + column
			if cells[index]:
				# Colour by position, so the grid reads as the classic red/blue
				# one without the colour carrying meaning a player would have to
				# learn. One bit per cell is the encoding; this is the paint.
				var tint := DOT_RED if (row + column) % 2 == 0 else DOT_BLUE
				_grid.draw_circle(box.get_center(), CELL_SIZE * 0.31, tint)
			if Vector2i(column, row) == cursor:
				_grid.draw_rect(box.grow(6.0), CURSOR, false, 4.0)


func _blank() -> Array[bool]:
	var out: Array[bool] = []
	out.resize(Password.CELLS)
	out.fill(false)
	return out
