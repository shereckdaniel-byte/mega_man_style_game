## The options screen: volume, window, the colourblind cue, and rebinding.
##
## **Reachable from the title and from the pause menu**, which are the two
## places anybody looks. The pause menu already lists the controls (it reads the
## live `InputMap`, so it has always shown what the game responds to rather than
## what somebody last wrote down); this is where they can be changed.
##
## ### Every change applies immediately and saves immediately
##
## No OK button and no cancel. A settings screen with an apply step is a screen
## where somebody turns the volume down, hears nothing change, turns it down
## again, and then presses cancel. Applying on the frame the value moves means
## the slider *is* the volume, which is the only mental model worth having.
##
## The cost is that there is no undo, which is why the last row is a reset.
class_name OptionsScreen
extends CanvasLayer

signal closed()

const BACKDROP := Color(0.05, 0.06, 0.10, 0.97)
const TEXT := Color(0.86, 0.90, 0.98)
const DIM := Color(0.42, 0.46, 0.56)
const CURSOR := Color(0.98, 0.86, 0.35)

## One row per line, in the order they are drawn.
enum Row {
	MASTER, MUSIC, SFX, SCALE, FULLSCREEN, COLOURBLIND, REBIND, RESET, BACK,
}

## How much a left/right press moves a volume. A twentieth: fine enough to find
## a level, coarse enough to cross the range without holding the key.
const VOLUME_STEP := 0.05

var cursor: Row = Row.MASTER
## The action currently waiting for a key, or empty.
var listening: StringName = &""

var _rows: Array[Label] = []
var _status: Label
var _rebind_index := 0


## Opens over whatever is on screen.
static func open(parent: Node) -> OptionsScreen:
	var screen := OptionsScreen.new()
	screen.name = "OptionsScreen"
	parent.add_child(screen)
	return screen


func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Settings.is_loaded():
		Settings.load_settings()
	_build()
	_refresh()


func close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func move_cursor(delta: int) -> void:
	if listening != &"":
		return
	cursor = wrapi(cursor + delta, 0, Row.size()) as Row
	Sfx.play(&"cursor")
	_refresh()


## Left/right on a row that has a value. Returns true if anything moved.
func adjust(delta: int) -> bool:
	match cursor:
		Row.MASTER:
			Settings.master = clampf(Settings.master + float(delta) * VOLUME_STEP, 0.0, 1.0)
		Row.MUSIC:
			Settings.music = clampf(Settings.music + float(delta) * VOLUME_STEP, 0.0, 1.0)
		Row.SFX:
			Settings.sfx = clampf(Settings.sfx + float(delta) * VOLUME_STEP, 0.0, 1.0)
		Row.SCALE:
			Settings.step_scale(delta)
		Row.FULLSCREEN:
			Settings.fullscreen = not Settings.fullscreen
		Row.COLOURBLIND:
			Settings.colourblind = not Settings.colourblind
		Row.REBIND:
			_rebind_index = wrapi(_rebind_index + delta, 0,
				Settings.REBINDABLE.size())
		_:
			return false
	Settings.apply()
	Settings.save_settings()
	# The sound plays *after* the volume moves, so the player hears what they
	# just chose rather than what it was.
	Sfx.play(&"cursor")
	_refresh()
	return true


## Confirm. On most rows this is the same as nudging right; on the rebind row it
## starts listening, and on the last two it does what they say.
func confirm() -> bool:
	match cursor:
		Row.REBIND:
			listening = Settings.REBINDABLE[_rebind_index]
			Sfx.play(&"confirm")
			_refresh()
			return true
		Row.RESET:
			Settings.reset_bindings()
			Settings.save_settings()
			Sfx.play(&"confirm")
			_say("CONTROLS RESET")
			_refresh()
			return true
		Row.BACK:
			Sfx.play(&"confirm")
			close()
			return true
		_:
			return adjust(1)


## Takes a key for the action being listened for.
##
## **Refuses the pause key**, because pause is how this screen is left and a
## player who binds it to something else while inside the screen has to guess
## their way out.
func take_key(event: InputEventKey) -> bool:
	if listening == &"" or event == null:
		return false
	if event.physical_keycode == KEY_ESCAPE:
		listening = &""
		Sfx.play(&"refuse")
		_say("CANCELLED")
		_refresh()
		return false
	Settings.rebind(listening, event)
	Settings.save_settings()
	listening = &""
	Sfx.play(&"confirm")
	_say("BOUND")
	_refresh()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if listening != &"":
		if event is InputEventKey and event.pressed and not event.is_echo():
			take_key(event as InputEventKey)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_up"):
		move_cursor(-1)
	elif event.is_action_pressed(&"move_down"):
		move_cursor(1)
	elif event.is_action_pressed(&"move_left"):
		adjust(-1)
	elif event.is_action_pressed(&"move_right"):
		adjust(1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"shoot"):
		confirm()
	elif event.is_action_pressed(&"pause"):
		close()
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

	var title := Label.new()
	title.name = "Title"
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", TEXT)
	title.add_theme_font_size_override(&"font_size", 52)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 80.0
	panel.add_child(title)

	for i in Row.size():
		var row := Label.new()
		row.name = "Row%d" % i
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override(&"font_size", 34)
		row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		row.position.y = 230.0 + float(i) * 62.0
		panel.add_child(row)
		_rows.append(row)

	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", DIM)
	_status.add_theme_font_size_override(&"font_size", 26)
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.position.y = 830.0
	panel.add_child(_status)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "← → change · FIRE select · PAUSE back"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", DIM)
	hint.add_theme_font_size_override(&"font_size", 24)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.position.y = 900.0
	panel.add_child(hint)


## What each row says right now. Public because it is the whole visible state of
## the screen and a test that could not read it would be testing nothing.
func row_text(row: Row) -> String:
	match row:
		Row.MASTER:
			return "MASTER        %s" % _meter(Settings.master)
		Row.MUSIC:
			return "MUSIC         %s" % _meter(Settings.music)
		Row.SFX:
			return "SOUND         %s" % _meter(Settings.sfx)
		Row.SCALE:
			return "WINDOW        %d%%" % int(Settings.scale * 100.0)
		Row.FULLSCREEN:
			return "FULLSCREEN    %s" % ("ON" if Settings.fullscreen else "OFF")
		Row.COLOURBLIND:
			return "PANEL CUE     %s" % ("HIGH CONTRAST" if Settings.colourblind else "NORMAL")
		Row.REBIND:
			var action := Settings.REBINDABLE[_rebind_index]
			if listening == action:
				return "%s   PRESS A KEY" % _action_name(action)
			return "%s   %s" % [_action_name(action), Settings.binding_text(action)]
		Row.RESET:
			return "RESET CONTROLS"
		Row.BACK:
			return "BACK"
	return ""


func _refresh() -> void:
	for i in _rows.size():
		var here := i == int(cursor)
		_rows[i].text = ("> %s <" if here else "  %s  ") % row_text(i as Row)
		_rows[i].add_theme_color_override(&"font_color", CURSOR if here else TEXT)


## A ten-segment bar. Numbers are what the file holds; a bar is what a person
## reads at a glance, and this screen is read at a glance.
func _meter(value: float) -> String:
	var filled := int(round(value * 10.0))
	return "%s%s  %3d%%" % ["#".repeat(filled), ".".repeat(10 - filled),
		int(round(value * 100.0))]


func _action_name(action: StringName) -> String:
	return String(action).replace("_", " ").to_upper().rpad(14)


func _say(message: String) -> void:
	if _status != null:
		_status.text = message
