## The password screen, driven as a player would drive it.
##
## The codec is proved in `test_password.gd`; what is here is the screen's own
## behaviour -- that it opens showing the run you are in, that a wrong grid is
## refused without wiping what you typed, and that a right one actually changes
## the run rather than only saying it did.
extends TestCase

const ScreenScript := preload("res://scenes/ui/password_screen.gd")

var root: Node
var screen: PasswordScreen
var state: Node
var _saved: Dictionary = {}


func is_async() -> bool:
	return true


func before_each_async() -> void:
	state = tree.root.get_node_or_null(^"/root/GameState")
	if state != null:
		_saved = state.to_dict()
	root = Node.new()
	tree.root.add_child(root)
	await tree.process_frame


func after_each_async() -> void:
	if is_instance_valid(root):
		root.queue_free()
	if state != null and not _saved.is_empty():
		state.from_dict(_saved)
	await tree.process_frame


func _open() -> PasswordScreen:
	screen = ScreenScript.open(root)
	await tree.process_frame
	return screen


# --- It opens on the run you are in -----------------------------------------------

## **The screen arrives already showing your password.** That is the "write this
## down" half, and it costs nothing because the grid has to be drawn anyway --
## the alternative is two drawings of the same thing that the player has to
## trust agree.
func test_it_opens_showing_the_current_run() -> void:
	if state == null:
		return
	state.bosses_defeated = 0b10110100
	state.items_unlocked = 5
	state.etanks = 6
	await _open()
	assert_eq(screen.as_text(), Password.to_text(Password.encode(state.to_dict())),
		"the screen opened on a grid that is not this run's password")


func test_the_cursor_starts_at_the_top_left_and_stays_on_the_grid() -> void:
	await _open()
	assert_eq(screen.cursor, Vector2i.ZERO, "the cursor did not start at A1")
	# Walked off every edge: a cursor that leaves the grid indexes past the end
	# of the cell array, which is a crash rather than a wrong answer.
	for _i in 10:
		screen.move_cursor(Vector2i(-1, -1))
	assert_eq(screen.cursor, Vector2i.ZERO)
	for _i in 10:
		screen.move_cursor(Vector2i(1, 1))
	assert_eq(screen.cursor, Vector2i(Password.COLUMNS - 1, Password.ROWS - 1))


func test_toggling_marks_the_cell_under_the_cursor() -> void:
	await _open()
	screen.cursor = Vector2i(2, 3)
	var index := 3 * Password.COLUMNS + 2
	var before: bool = screen.cells[index]
	screen.toggle()
	assert_eq(screen.cells[index], not before, "the cell did not toggle")
	screen.toggle()
	assert_eq(screen.cells[index], before, "toggling twice did not return it")


# --- Entering one ------------------------------------------------------------------

## A password typed in actually changes the run, rather than only reporting that
## it did.
func test_a_valid_password_loads_the_run() -> void:
	if state == null:
		return
	var wanted := {"bosses_defeated": 0b01101011, "items_unlocked": 3, "etanks": 4}
	var cells := Password.encode(wanted)
	state.reset()
	await _open()
	screen.cells = cells.duplicate()
	assert_true(screen.submit(), "a valid password was refused")
	assert_true(screen.loaded(), "the screen did not record the load")
	assert_eq(state.bosses_defeated, int(wanted["bosses_defeated"]))
	assert_eq(state.items_unlocked, int(wanted["items_unlocked"]))
	assert_eq(state.etanks, int(wanted["etanks"]))


## **A refused password keeps what you typed.** Wiping the grid on a wrong
## answer is what makes people give up: twenty-five dots is a lot to re-enter
## when the mistake was one of them, and the checksum is specifically good at
## catching one of them.
func test_a_refused_password_keeps_the_grid() -> void:
	if state == null:
		return
	var cells := Password.encode({"bosses_defeated": 0b11001010,
		"items_unlocked": 1, "etanks": 2})
	cells[7] = not cells[7]  # one wrong dot
	await _open()
	screen.cells = cells.duplicate()
	var before := screen.as_text()
	assert_false(screen.submit(), "a corrupted password was accepted")
	assert_false(screen.loaded(), "the screen recorded a load that did not happen")
	assert_eq(screen.as_text(), before, "the grid was cleared on a refusal")


## And a refusal leaves the run alone -- a half-applied password would be worse
## than none.
func test_a_refused_password_does_not_touch_the_run() -> void:
	if state == null:
		return
	state.reset()
	state.bosses_defeated = 0b00000011
	await _open()
	var blank: Array[bool] = []
	blank.resize(Password.CELLS)
	blank.fill(true)  # all twenty-five marked: the reserved cells refuse it
	screen.cells = blank
	assert_false(screen.submit())
	assert_eq(state.bosses_defeated, 0b00000011,
		"a refused password changed the run anyway")


## Closing reports whether anything was loaded, which is what the stage select
## behind it needs in order to know whether to rebuild.
func test_closing_reports_whether_it_loaded() -> void:
	var said: Array[bool] = []
	await _open()
	screen.finished.connect(func(loaded: bool) -> void: said.append(loaded))
	screen.close()
	await tree.process_frame
	assert_eq(said.size(), 1, "closing did not report")
	assert_false(said[0], "closing without entering anything reported a load")


## The screen is reachable from the stage select, which is the only place it can
## be reached from until M8 writes a title.
func test_the_stage_select_can_open_it() -> void:
	var select: Node = (load("res://scenes/ui/stage_select.tscn") as PackedScene).instantiate()
	root.add_child(select)
	await tree.process_frame
	var opened = select.open_password()
	await tree.process_frame
	assert_true(opened is PasswordScreen, "the select did not open a password screen")
	opened.close()
	await tree.process_frame
