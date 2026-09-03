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


func _refresh_rows() -> void:
	rows.clear()
	if _weapons != null:
		for id: StringName in _weapons.unlocked():
			rows.append(id)
	rows.append(ETANK_ROW)
	rows.append(RESTART_ROW)
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
	if id == RESTART_ROW:
		return true
	if id == ETANK_ROW:
		return _state != null and _state.etanks > 0
	if _weapons == null:
		return true
	return _weapons.can_fire(id)
