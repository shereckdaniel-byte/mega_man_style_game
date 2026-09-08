## The pause sub-screen: weapons, ammo, and E-tanks.
##
## In the original this is not a settings menu, it is *part of play* -- the only
## way to change weapon mid-stage and the only way to spend an E-tank, both of
## which are decisions made under pressure with the boss still on screen behind
## the panel. So it stops the tree (`get_tree().paused`) rather than merely
## hiding the game, and it runs on PROCESS_MODE_ALWAYS so it is the one thing
## still ticking.
##
## Everything it does is exposed as a method -- `move_selection`, `confirm`,
## `use_etank` -- with input only calling those. A test drives the menu the same
## way a player does, without synthesising input events.
class_name PauseMenu
extends CanvasLayer

signal opened()
signal closed()
signal weapon_selected(weapon_id: StringName)
signal etank_used(remaining: int)
## The player asked to start the stage again. The stage decides what that means;
## the menu only reports it.
signal restart_requested()
## What the last confirm did, or refused to do. For the status line and tests.
signal reported(message: String)

const BACKDROP := Color(0.03, 0.05, 0.10, 0.90)
const ROW_COLOUR := Color(0.78, 0.86, 0.96)
const SELECTED_COLOUR := Color(1.0, 0.88, 0.42)
const DIM_COLOUR := Color(0.45, 0.52, 0.64)

## The E-tank row sits after the weapons and is selected like one of them.
const ETANK_ROW := &"__etank"
## And a restart row after that.
##
## Not in the original, and not pretending to be. It is here because there is no
## title screen yet and no stage select, so the only way to try the stage again
## is to close the game and reopen it -- which makes an evening of playtesting
## considerably worse than it needs to be. It can go when M8 brings a real
## front end, or stay: plenty of modern releases keep one.
const RESTART_ROW := &"__restart"

## And a resume row last, which exists because the HUD grew a menu button.
##
## Opening the menu with the mouse and then having no way out of it with the
## mouse is not a menu, it is a trap. The pause key still closes it and always
## did; this is the visible half of that, for a player who found the menu by
## clicking rather than by reading a key binding.
const RESUME_ROW := &"__resume"

## What each binding is *for*, in display order.
##
## The keys themselves are **not** in this table -- they are read from the live
## `InputMap` (see `control_lines`), so this list cannot drift out of step with
## the bindings the way a hand-written key list would. What a human has to write
## down is the part the engine does not know: which action is "fire" and which
## is "change weapon".
##
## `slide` is the interesting row. It is deliberately not an action -- it is
## down plus jump, as in Mega Man 3 (see `tools/bootstrap_input_map.gd`) -- so it
## has no InputMap entry to read and is spelled out from the two actions that
## make it. A controls screen that lists only the actions would leave out the
## one move nobody guesses.
## `primary_only` keeps just the first key bound to each action, and exists for
## exactly one row: "DOWN / S + Z / SPACE" is not a control, it is a puzzle.
## Where two actions are combined, the alternates are noise.
const CONTROL_ROWS: Array[Dictionary] = [
	{"label": "MOVE", "actions": [&"move_left", &"move_right"]},
	{"label": "CLIMB", "actions": [&"move_up", &"move_down"]},
	{"label": "JUMP", "actions": [&"jump"]},
	{"label": "SLIDE", "actions": [&"move_down", &"jump"], "joiner": " + ",
		"primary_only": true},
	{"label": "FIRE", "actions": [&"shoot"]},
	{"label": "SWORD", "actions": [&"melee"]},
	{"label": "CHANGE WEAPON", "actions": [&"weapon_prev", &"weapon_next"],
		"joiner": ", "},
	{"label": "THIS MENU", "actions": [&"pause"]},
	{"label": "LEDGER", "actions": [&"debug_overlay"]},
]

var is_open := false
## Row ids in display order: the unlocked weapon ids, then ETANK_ROW.
var rows: Array[StringName] = []
var selected := 0

var _player: Player = null
var _weapons: Node = null
var _state: Node = null
var _panel: ColorRect
var _list: VBoxContainer
var _status: Label
var _labels: Array[Label] = []


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_weapons = get_node_or_null(^"/root/WeaponManager")
	_state = get_node_or_null(^"/root/GameState")
	_build()
	_panel.visible = false


## The player whose health an E-tank refills. Optional: the menu still opens and
## still switches weapons without one.
func bind(player: Player) -> void:
	_player = player


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_refresh_rows()
	_panel.visible = true
	get_tree().paused = true
	_report("")
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	closed.emit()


## Moves the highlight. Wraps, because a list this short is faster to wrap than
## to clamp.
func move_selection(delta: int) -> void:
	if rows.is_empty():
		return
	selected = wrapi(selected + delta, 0, rows.size())
	_redraw_rows()


func selected_row() -> StringName:
	if selected < 0 or selected >= rows.size():
		return &""
	return rows[selected]


## Acts on the highlighted row: equip a weapon, or spend an E-tank.
## Acts on the highlighted row and **says what happened**.
##
## The saying is the part that was missing. On a fresh run the rows are the
## buster, an E-Tank the player does not have, and Restart -- so pressing confirm
## on two of the three correctly does nothing, and did it in complete silence. A
## playtester reported the menu as broken, which is the right conclusion from the
## evidence: a refusal that looks identical to a dead button is a dead button.
func confirm() -> bool:
	var row := selected_row()
	if row == &"":
		return false
	if row == ETANK_ROW:
		var before: int = _state.etanks if _state != null else 0
		var used := use_etank()
		if used:
			_report("E-TANK USED")
		elif before <= 0:
			_report("NO E-TANKS")
		else:
			_report("ALREADY AT FULL HEALTH")
		return used
	if row == RESUME_ROW:
		close()
		return true
	if row == RESTART_ROW:
		# Closed first: the stage is about to be rebuilt underneath this menu,
		# and a menu left open would keep the tree paused with nothing to
		# unpause it.
		_report("RESTARTING")
		close()
		restart_requested.emit()
		return true
	if _weapons == null or not _weapons.select(row):
		_report("UNAVAILABLE")
		return false
	weapon_selected.emit(row)
	_report("%s EQUIPPED" % _row_text(row).strip_edges().to_upper())
	_redraw_rows()
	return true


## The controls, as "LABEL" / "KEYS" pairs, in `CONTROL_ROWS` order.
##
## **The keys come from the live `InputMap`, not from a list in this file.** A
## hand-written controls screen is a second copy of the bindings, and the copy is
## the one that goes stale -- `melee` spent two milestones bound in
## `project.godot` and absent from the generator that is supposed to own the
## bindings, and nothing noticed. Reading the map means this screen is wrong only
## if the game is wrong.
##
## Keyboard only, deliberately. Every action is also on the pad, but printing
## both doubles the width of every row to tell a player holding a controller
## something the buttons already tell them.
func control_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec in CONTROL_ROWS:
		var joiner: String = spec.get("joiner", "   ")
		var primary_only: bool = spec.get("primary_only", false)
		var parts: Array[String] = []
		for action: StringName in spec["actions"]:
			var keys := _keys_for(action, primary_only)
			if keys != "":
				parts.append(keys)
		if parts.is_empty():
			# An action nothing is bound to is left out rather than listed
			# blank: a controls screen naming a key you do not have is worse
			# than one that is short.
			continue
		out.append({"label": String(spec["label"]), "keys": joiner.join(parts)})
	return out


## Every keyboard key bound to one action, as "Z, SPACE", or just the first when
## `primary_only`.
##
## A comma rather than a slash separates the alternates, because a slash is what
## a reader takes for "one or the other of two *different* controls" once there
## are two actions on the same row.
func _keys_for(action: StringName, primary_only: bool = false) -> String:
	if not InputMap.has_action(action):
		return ""
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		# Bindings are stored as physical keycodes so they follow the key's
		# position on any layout; that is also the one that has a name here.
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		var text := OS.get_keycode_string(code).to_upper()
		if text != "" and not names.has(text):
			names.append(text)
		if primary_only and not names.is_empty():
			break
	return ", ".join(names)


## Shows one line of feedback under the rows until the next confirm.
func _report(message: String) -> void:
	if _status != null:
		_status.text = message
	reported.emit(message)


## Spends one E-tank and refills the player to full.
##
## Refused when the player is already at full health, which is the original's
## behaviour and matters: an E-tank spent at full health is simply gone, and
## that is a mistake the menu should not let the player make.
func use_etank() -> bool:
	if _state == null or _player == null:
		return false
	if _state.etanks <= 0:
		return false
	if _player.health.current >= _player.health.max_hp:
		return false
	if not _state.consume_etank():
		return false
	_player.health.heal(_player.health.max_hp)
	etank_used.emit(_state.etanks)
	_refresh_rows()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed(&"move_up"):
		move_selection(-1)
	elif event.is_action_pressed(&"move_down"):
		move_selection(1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"shoot"):
		confirm()
	get_viewport().set_input_as_handled()


# --- Layout --------------------------------------------------------------------

func _build() -> void:
	_panel = ColorRect.new()
	_panel.name = "Panel"
	_panel.color = BACKDROP
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 18)
	_panel.add_child(box)

	var heading := Label.new()
	heading.text = "WEAPONS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override(&"font_color", ROW_COLOUR)
	heading.add_theme_font_size_override(&"font_size", 44)
	box.add_child(heading)

	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override(&"separation", 10)
	box.add_child(_list)

	# The line that says what the last confirm did. Empty until something is
	# pressed, so it is an answer rather than a label.
	_status = Label.new()
	_status.name = "Status"
	_status.text = ""
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", DIM_COLOUR)
	_status.add_theme_font_size_override(&"font_size", 26)
	box.add_child(_status)

	_build_controls(box)


## The controls block under the weapon rows.
##
## Dimmer and smaller than the rows above it, because it is reference rather
## than choice: the rows are things you press this screen to do, and this is a
## list you read once and then stop seeing. Drawn as a grid so the keys line up
## in a column -- ragged keys are what makes a printed control list hard to scan.
func _build_controls(into: VBoxContainer) -> void:
	var lines := control_lines()
	if lines.is_empty():
		return

	var heading := Label.new()
	heading.name = "ControlsHeading"
	heading.text = "CONTROLS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override(&"font_color", DIM_COLOUR)
	heading.add_theme_font_size_override(&"font_size", 26)
	into.add_child(heading)

	var grid := GridContainer.new()
	grid.name = "Controls"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 40)
	grid.add_theme_constant_override(&"v_separation", 4)
	# Centred as a block: a left-aligned grid inside a centred column would sit
	# against the screen's left edge with the menu floating in the middle.
	var centre := HBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(grid)
	into.add_child(centre)

	for line in lines:
		var label := Label.new()
		label.text = String(line["label"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override(&"font_color", DIM_COLOUR)
		label.add_theme_font_size_override(&"font_size", 22)
		grid.add_child(label)

		var keys := Label.new()
		keys.text = String(line["keys"])
		keys.add_theme_color_override(&"font_color", ROW_COLOUR)
		keys.add_theme_font_size_override(&"font_size", 22)
		grid.add_child(keys)


func _refresh_rows() -> void:
	rows.clear()
	if _weapons != null:
		for id: StringName in _weapons.unlocked():
			rows.append(id)
	rows.append(ETANK_ROW)
	rows.append(RESTART_ROW)
	rows.append(RESUME_ROW)
	# Open on whatever is equipped, so the common case -- open, switch back,
	# close -- does not start by hunting for the cursor.
	if _weapons != null:
		var at := rows.find(_weapons.current)
		selected = at if at >= 0 else 0
	selected = clampi(selected, 0, rows.size() - 1)
	_rebuild_labels()


func _rebuild_labels() -> void:
	for label in _labels:
		if is_instance_valid(label):
			label.queue_free()
	_labels.clear()
	for id in rows:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 34)
		_list.add_child(label)
		_labels.append(label)
	_redraw_rows()


func _redraw_rows() -> void:
	for i in _labels.size():
		var label := _labels[i]
		if not is_instance_valid(label):
			continue
		label.text = _row_text(rows[i])
		var colour := ROW_COLOUR
		if i == selected:
			colour = SELECTED_COLOUR
		elif not _row_available(rows[i]):
			colour = DIM_COLOUR
		label.add_theme_color_override(&"font_color", colour)


func _row_text(id: StringName) -> String:
	if id == RESUME_ROW:
		return "RESUME"
	if id == RESTART_ROW:
		return "RESTART STAGE"
	if id == ETANK_ROW:
		var count: int = _state.etanks if _state != null else 0
		return "E-TANK   x%d" % count
	var equipped := "*" if _weapons != null and _weapons.current == id else " "
	if _weapons == null:
		return "%s %s" % [equipped, String(id).to_upper()]
	var data: WeaponData = _weapons.data_for(id)
	var label: String = data.display_name if data != null else String(id).capitalize()
	if id == _weapons.BUSTER:
		return "%s %s" % [equipped, label.to_upper()]
	return "%s %-16s %2d/%2d" % [equipped, label.to_upper(),
		_weapons.get_ammo(id), _weapons.max_ammo(id)]


func _row_available(id: StringName) -> bool:
	if id == RESUME_ROW or id == RESTART_ROW:
		return true
	if id == ETANK_ROW:
		return _state != null and _state.etanks > 0
	if _weapons == null:
		return true
	return _weapons.can_fire(id)
