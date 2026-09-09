## The title screen: the first thing anybody sees, and the only screen that
## decides whether a run continues or starts over.
##
## **Three rows, and the middle one is the whole reason this screen exists.**
## Boot has read slot 0 since M6, so a returning player already had their
## progress when they arrived at the stage select -- with no way to *not* have
## it. Starting fresh meant deleting a file by hand. A title screen with
## CONTINUE and NEW GAME on it is the option that read was always missing.
##
## `CONTINUE` is dimmed and refuses when there is no save, rather than being
## hidden: a row that appears and disappears makes the menu change shape between
## visits, which is the same argument the stage select makes about its unbuilt
## cells.
class_name TitleScreen
extends CanvasLayer

## The player chose. `fresh` is true for a new game.
signal started(fresh: bool)

const BACKDROP := Color(0.05, 0.06, 0.10, 1.0)
const NAME_COLOUR := Color(0.86, 0.90, 0.98)
const DIM := Color(0.40, 0.44, 0.54)
const CURSOR := Color(0.98, 0.86, 0.35)
const SEA := Color(0.14, 0.30, 0.44)
const SEA_LOW := Color(0.07, 0.14, 0.24)

const ROW_CONTINUE := 0
const ROW_NEW := 1
const ROW_PASSWORD := 2
const ROWS := 3

var cursor := ROW_CONTINUE

var _rows: Array[Label] = []
var _status: Label
var _has_save := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_has_save = SaveGame.exists(0)
	_build()
	# Open on something that works. A cursor sitting on a row that refuses is
	# the first press of the game being a "no".
	cursor = ROW_CONTINUE if _has_save else ROW_NEW
	_refresh()
	Music.play(&"jingle_ending")


func has_save() -> bool:
	return _has_save


func move_cursor(delta: int) -> void:
	cursor = wrapi(cursor + delta, 0, ROWS)
	Sfx.play(&"cursor")
	_refresh()


## Takes the highlighted row, or says why it will not.
func confirm() -> bool:
	match cursor:
		ROW_CONTINUE:
			if not _has_save:
				_say("NO SAVED GAME")
				return false
			_begin(false)
			return true
		ROW_NEW:
			_begin(true)
			return true
		ROW_PASSWORD:
			open_password()
			return true
	return false


## The password screen, over the title. Reachable from here as well as from the
## stage select, because this is where somebody arrives holding one written on
## a piece of paper.
func open_password() -> PasswordScreen:
	var screen := PasswordScreen.open(self)
	screen.finished.connect(_on_password_finished)
	return screen


func _on_password_finished(loaded: bool) -> void:
	if not loaded:
		return
	# A loaded password *is* a continue: the state is already in GameState.
	Sfx.play(&"confirm")
	started.emit(false)
	_go(SceneRouter.STAGE_SELECT)


## **New game clears the run before it starts one**, which is the whole point of
## the row. Reading the save at boot and then not using it would leave a
## half-loaded state behind -- the eight bits gone and the E-tanks still there.
func _begin(fresh: bool) -> void:
	Sfx.play(&"confirm")
	var state := get_node_or_null(^"/root/GameState")
	if fresh and state != null:
		state.reset()
		var weapons := get_node_or_null(^"/root/WeaponManager")
		if weapons != null:
			weapons.reset()
	started.emit(fresh)
	_go(SceneRouter.STAGE_SELECT)


func _go(path: String) -> void:
	var router := get_node_or_null(^"/root/SceneRouter")
	if router != null:
		router.goto(path)
	else:
		get_tree().call_deferred("change_scene_to_file", path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_up"):
		move_cursor(-1)
	elif event.is_action_pressed(&"move_down"):
		move_cursor(1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"shoot"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Layout ------------------------------------------------------------------------

func _build() -> void:
	var panel := ColorRect.new()
	panel.name = "Backdrop"
	panel.color = BACKDROP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# A horizon, because the whole game is about a drowned coast and the title
	# is the one screen with room to say so.
	var sea := Sea.new()
	sea.name = "Sea"
	panel.add_child(sea)

	var title := Label.new()
	title.name = "Title"
	title.text = "SEAWALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", NAME_COLOUR)
	title.add_theme_font_size_override(&"font_size", 96)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 180.0
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "a drowned coast, and eight machines that did it"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(&"font_color", DIM)
	subtitle.add_theme_font_size_override(&"font_size", 26)
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position.y = 296.0
	panel.add_child(subtitle)

	var names := ["CONTINUE", "NEW GAME", "PASSWORD"]
	for i in ROWS:
		var row := Label.new()
		row.name = names[i].replace(" ", "")
		row.text = names[i]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override(&"font_size", 40)
		row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		row.position.y = 560.0 + float(i) * 64.0
		panel.add_child(row)
		_rows.append(row)

	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", DIM)
	_status.add_theme_font_size_override(&"font_size", 26)
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.position.y = 800.0
	panel.add_child(_status)


func _refresh() -> void:
	for i in _rows.size():
		var available := i != ROW_CONTINUE or _has_save
		var colour := DIM
		if available:
			colour = CURSOR if i == cursor else NAME_COLOUR
		elif i == cursor:
			# Highlighted and unavailable still reads as highlighted, or the
			# cursor disappears when it lands here.
			colour = DIM.lerp(CURSOR, 0.45)
		_rows[i].add_theme_color_override(&"font_color", colour)
		_rows[i].text = ("> %s <" if i == cursor else "%s") % _row_text(i)


func _row_text(index: int) -> String:
	if index == ROW_CONTINUE and not _has_save:
		return "CONTINUE — NO SAVE"
	return ["CONTINUE", "NEW GAME", "PASSWORD"][index]


func _say(message: String) -> void:
	Sfx.play(&"refuse")
	if _status != null:
		_status.text = message


## The horizon. Drawn rather than loaded, like every fortress backdrop, so the
## title screen does not wait on an art pass to exist.
class Sea:
	extends Control

	const HIGH := Color(0.14, 0.30, 0.44)
	const LOW := Color(0.07, 0.14, 0.24)
	const WALL := Color(0.16, 0.17, 0.20)

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var horizon := size.y * 0.42
		for i in 10:
			var t := float(i) / 9.0
			draw_rect(Rect2(Vector2(0.0, horizon + t * (size.y - horizon) * 0.55),
				Vector2(w, (size.y - horizon) * 0.07)),
				HIGH.lerp(LOW, t))
		# The wall itself, low and flat across the bottom third.
		draw_rect(Rect2(Vector2(0.0, size.y * 0.78), Vector2(w, size.y * 0.22)), WALL)
		for i in 26:
			var x := w * float(i) / 26.0
			draw_rect(Rect2(Vector2(x, size.y * 0.78), Vector2(3.0, size.y * 0.22)),
				WALL.darkened(0.3))
