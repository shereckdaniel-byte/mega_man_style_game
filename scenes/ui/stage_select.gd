## The stage select: eight Robot Masters in a 3x3 grid, playable in any order.
##
## The promise in docs/PLAN.md section 1 -- "8 Robot Master stages playable in
## any order" -- with nothing to select them from until now. The game booted
## straight into stage 1, which is why a playtester's seventh note was "there is
## no menu to be able to select which stage I want yet".
##
## **Unbuilt stages are shown, not hidden.** Six of the eight have a boss, a
## portrait and a name and no level behind them yet. Listing only what exists
## would make the grid change shape as stages land -- and a 3x3 select screen
## whose cells move is the one thing this screen must never do, because the
## player's memory of where a stage *is* is the whole interface. So all eight
## have a cell from the start; the six without a level read as unavailable and
## refuse to be entered, which is honest and keeps the layout still.
##
## The centre cell is the fortress slot. It stays on the grid whatever state it
## is in, for the same reason: the player's memory of where a thing *is* is the
## interface, and a cell that appears only once the fortress opens is a cell
## they have to find at the moment they most want to press it.
extends CanvasLayer

## Emitted when the player picks a stage that exists. The scene change goes
## through SceneRouter; this is for tests and for anything that wants to know.
signal stage_chosen(index: int)
## A refused pick, with why. Same reasoning as the pause menu's report line: a
## refusal that looks identical to a dead button is a dead button.
signal refused(message: String)

const BACKDROP := Color(0.05, 0.06, 0.10, 1.0)
const CELL := Color(0.13, 0.15, 0.22)
const CELL_LOCKED := Color(0.09, 0.10, 0.14)
const CURSOR := Color(0.98, 0.86, 0.35)
const NAME_COLOUR := Color(0.86, 0.90, 0.98)
const DIM_COLOUR := Color(0.42, 0.46, 0.56)
const DEFEATED := Color(0.45, 0.85, 0.55)

## Grid geometry in pixels, at the project's 1920x1080.
const CELL_SIZE := Vector2(300.0, 260.0)
const CELL_GAP := 26.0

var cursor := Vector2i(0, 0)

var _state: Node
var _cells: Dictionary = {}          # Vector2i -> Control
var _portraits: Dictionary = {}      # Vector2i -> TextureRect
var _status: Label
var _title: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_state = get_node_or_null(^"/root/GameState")
	_build()
	# Open on something the player can actually enter, so the first press of the
	# confirm button does something. Landing the cursor on a locked cell and
	# making them hunt is a worse first second.
	var playable: Array[int] = StageRoster.built()
	if not playable.is_empty():
		cursor = StageRoster.grid_position(playable[0])
	_refresh()


## Moves the cursor. Wraps in both axes, like the original's.
func move_cursor(delta: Vector2i) -> void:
	cursor = Vector2i(wrapi(cursor.x + delta.x, 0, 3), wrapi(cursor.y + delta.y, 0, 3))
	_refresh()


func selected_index() -> int:
	return StageRoster.at(cursor)


## Enters the highlighted stage, or says why it will not.
func confirm() -> bool:
	var index := selected_index()
	if index < 0:
		return _confirm_fortress()
	var row := StageRoster.entry(index)
	if not StageRoster.is_built(index):
		_report("%s — NOT BUILT YET" % String(row["stage"]).to_upper())
		return false
	if _state != null:
		_state.current_stage = index
	stage_chosen.emit(index)
	var router := get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto(String(row["scene"]))
	else:
		get_tree().call_deferred("change_scene_to_file", String(row["scene"]))
	return true


## Why the centre cell will not open, or "" if it will.
##
## **Split out from the confirm so the decision can be read without taking it.**
## Confirming changes the scene, which makes the successful branch the one
## branch a test cannot exercise -- so the branch that will still be live when
## every fortress stage is on disk was the branch nothing checked. A query that
## returns the reason answers the same question and is safe to ask.
##
## Four answers rather than one, because "sealed" answered four different
## questions with the same word and only one of them was actionable. A player
## who has beaten six masters and a player who has finished the whole fortress
## are both being told no, and the useful part of the answer is the *reason*.
func fortress_refusal() -> String:
	if _state == null or not bool(_state.fortress_open()):
		return "THE FORTRESS IS SEALED — EIGHT MASTERS FIRST"
	var stage: int = int(_state.fortress_stage())
	if stage < 0:
		return "THE FORTRESS IS DOWN"
	if not StageRoster.fortress_is_built(stage):
		return "%s — NOT BUILT YET" % String(
			StageRoster.fortress_entry(stage)["name"]).to_upper()
	return ""


func _confirm_fortress() -> bool:
	var refusal := fortress_refusal()
	if not refusal.is_empty():
		_report(refusal)
		return false
	var row := StageRoster.fortress_entry(int(_state.fortress_stage()))
	# The fortress is not one of the eight, and `current_stage` is a boss index.
	# -1 is what the rest of the game already reads as "not in a master's stage".
	_state.current_stage = -1
	stage_chosen.emit(-1)
	var router := get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto(String(row["scene"]))
	else:
		get_tree().call_deferred("change_scene_to_file", String(row["scene"]))
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_left"):
		move_cursor(Vector2i(-1, 0))
	elif event.is_action_pressed(&"move_right"):
		move_cursor(Vector2i(1, 0))
	elif event.is_action_pressed(&"move_up"):
		move_cursor(Vector2i(0, -1))
	elif event.is_action_pressed(&"move_down"):
		move_cursor(Vector2i(0, 1))
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"shoot"):
		confirm()
	elif event.is_action_pressed(&"pause"):
		open_password()
	else:
		return
	get_viewport().set_input_as_handled()


## Opens the password screen over the grid.
##
## `pause` because it is the one action with nothing to do on this screen, and
## because "the menu key opens the menu" is a guess a player can make. There is
## no title screen yet -- `SceneRouter.TITLE` points at a scene M8 will write --
## so the select is where a password has to be enterable from, and it is not a
## bad home for it: it is the screen a run returns to.
func open_password() -> PasswordScreen:
	var screen := PasswordScreen.open(self)
	screen.finished.connect(_on_password_finished)
	return screen


## A loaded password changes which stages are cleared, so the grid is rebuilt.
func _on_password_finished(loaded: bool) -> void:
	if loaded:
		_refresh()
		_report("PASSWORD LOADED")


func _report(message: String) -> void:
	if _status != null:
		_status.text = message
	refused.emit(message)


# --- Layout --------------------------------------------------------------------

func _build() -> void:
	var panel := ColorRect.new()
	panel.name = "Backdrop"
	panel.color = BACKDROP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "SELECT STAGE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override(&"font_color", NAME_COLOUR)
	_title.add_theme_font_size_override(&"font_size", 46)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = 54.0
	panel.add_child(_title)

	var grid_size := Vector2(CELL_SIZE.x * 3.0 + CELL_GAP * 2.0,
		CELL_SIZE.y * 3.0 + CELL_GAP * 2.0)
	var origin := Vector2(1920.0, 1080.0) * 0.5 - grid_size * 0.5 + Vector2(0.0, 24.0)

	for y in 3:
		for x in 3:
			var cell := Vector2i(x, y)
			var box := _build_cell(cell)
			box.position = origin + Vector2(float(x) * (CELL_SIZE.x + CELL_GAP),
				float(y) * (CELL_SIZE.y + CELL_GAP))
			panel.add_child(box)
			_cells[cell] = box

	_status = Label.new()
	_status.name = "Status"
	_status.text = ""
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", DIM_COLOUR)
	_status.add_theme_font_size_override(&"font_size", 28)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.position.y = -96.0
	panel.add_child(_status)

	var help := Label.new()
	help.name = "Help"
	help.text = "ARROWS / WASD  MOVE      Z or X  SELECT"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override(&"font_color", DIM_COLOUR)
	help.add_theme_font_size_override(&"font_size", 22)
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.position.y = -52.0
	panel.add_child(help)


func _build_cell(cell: Vector2i) -> Control:
	var box := ColorRect.new()
	box.name = "Cell_%d_%d" % [cell.x, cell.y]
	box.size = CELL_SIZE
	box.color = CELL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var index := StageRoster.at(cell)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(CELL_SIZE.x, CELL_SIZE.y - 74.0)
	portrait.position = Vector2(0.0, 8.0)
	portrait.texture = _portrait_for(index)
	box.add_child(portrait)
	_portraits[cell] = portrait

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 27)
	name_label.size = Vector2(CELL_SIZE.x, 32.0)
	name_label.position = Vector2(0.0, CELL_SIZE.y - 62.0)
	box.add_child(name_label)

	var stage_label := Label.new()
	stage_label.name = "Stage"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override(&"font_size", 20)
	stage_label.size = Vector2(CELL_SIZE.x, 26.0)
	stage_label.position = Vector2(0.0, CELL_SIZE.y - 32.0)
	box.add_child(stage_label)

	# The selection border, built once and shown for whichever cell holds the
	# cursor. A StyleBox rather than a drawn rect so it sits above the portrait.
	var frame := Panel.new()
	frame.name = "Cursor"
	frame.size = CELL_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = CURSOR
	style.set_border_width_all(5)
	frame.add_theme_stylebox_override(&"panel", style)
	box.add_child(frame)
	return box


## The boss's portrait, cropped to the character.
##
## Loaded by path so the screen still opens while art is mid-regeneration, and
## cropped by `BossPortrait` so a character framed small inside its 256 px cell
## is not drawn smaller than the ones framed large — see that class for the
## measurements. Returns null for the fortress and for art that is not on disk.
## The centre cell's two lines: what the fortress is, and how far into it you are.
##
## It reads "FORTRESS / SEALED" until the eighth master falls and then names the
## stage you are up to, which is the only thing the grid ever tells a player
## they have not already been told -- the other eight cells describe what the
## player chose; this one describes what is left.
func _refresh_fortress_cell(name_label: Label, stage_label: Label) -> void:
	name_label.text = "FORTRESS"
	var open: bool = _state != null and bool(_state.fortress_open())
	var colour := NAME_COLOUR if open else DIM_COLOUR
	if not open:
		stage_label.text = "SEALED"
	else:
		var stage: int = int(_state.fortress_stage())
		if stage < 0:
			colour = DEFEATED
			stage_label.text = "CLEARED"
		elif not StageRoster.fortress_is_built(stage):
			colour = DIM_COLOUR
			stage_label.text = "NOT BUILT"
		else:
			stage_label.text = "%d/%d — %s" % [stage + 1,
				GameState.FORTRESS_COUNT,
				String(StageRoster.fortress_entry(stage)["name"]).to_upper()]
	name_label.add_theme_color_override(&"font_color", colour)
	stage_label.add_theme_color_override(&"font_color", colour)


func _portrait_for(index: int) -> Texture2D:
	if index < 0:
		return null
	var path: String = StageRoster.entry(index)["frames"]
	if not ResourceLoader.exists(path):
		return null
	return BossPortrait.of(load(path) as SpriteFrames)


func _refresh() -> void:
	for key: Vector2i in _cells:
		var box: ColorRect = _cells[key]
		var index := StageRoster.at(key)
		var built := index >= 0 and StageRoster.is_built(index)
		# Typed explicitly: `_state` is a Node, so its calls return Variant and
		# this project treats inference from Variant as an error.
		var beaten: bool = index >= 0 and _state != null \
			and bool(_state.is_boss_defeated(index))

		if index < 0:
			built = _state != null and bool(_state.fortress_open())
		box.color = CELL if built else CELL_LOCKED
		var name_label: Label = box.get_node(^"Name")
		var stage_label: Label = box.get_node(^"Stage")
		var portrait: TextureRect = _portraits[key]

		if index < 0:
			_refresh_fortress_cell(name_label, stage_label)
		else:
			var row := StageRoster.entry(index)
			name_label.text = String(row["boss"]).to_upper()
			stage_label.text = String(row["stage"]) if built else "NOT BUILT"
			var colour := NAME_COLOUR if built else DIM_COLOUR
			if beaten:
				colour = DEFEATED
				stage_label.text = "%s — CLEARED" % String(row["weapon"]).to_upper()
			name_label.add_theme_color_override(&"font_color", colour)
			stage_label.add_theme_color_override(&"font_color",
				DEFEATED if beaten else (NAME_COLOUR if built else DIM_COLOUR))

		# Unbuilt stages are dimmed rather than blanked: the player should see
		# who is coming, and a silhouette says "later" where an empty box says
		# "broken".
		portrait.modulate = Color(1, 1, 1, 1) if built else Color(0.34, 0.36, 0.44, 0.85)

		# The cursor. A tint alone was not enough to find at a glance -- it has to
		# compete with the cleared and unbuilt states, which are also colour --
		# so the selected cell gets a border as well, which no other state uses.
		var frame: Panel = box.get_node(^"Cursor")
		frame.visible = key == cursor
		if key == cursor:
			box.color = box.color.lerp(CURSOR, 0.22)


## The cell at a grid position, or null. Typed explicitly because a Dictionary
## lookup is a Variant and this project treats inference from Variant as an error.
func cell_node(cell: Vector2i) -> Control:
	var node: Variant = _cells.get(cell)
	return node as Control if node is Control else null
