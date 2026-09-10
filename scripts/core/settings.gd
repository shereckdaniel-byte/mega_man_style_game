## Everything the player can change about the game, and the file it lives in.
##
## **A static class rather than an autoload**, like `SaveGame`, `Password`,
## `Sfx` and `Music` before it. Settings are read in a handful of places and
## written from one screen; an autoload would be a node in the tree whose only
## job is to hold four values, and this project already has five autoloads.
##
## ### What is here and what is deliberately not
##
## Volume, window scale, fullscreen, the colourblind cue, and the input map.
## Not: difficulty, which docs/PLAN.md's scope excludes; and not the save slot,
## which is a *run* rather than a preference and belongs in `SaveGame`. A player
## who moves their settings between machines should not carry their progress
## with them, and a player who deletes their save should not lose their key
## bindings.
##
## ### Rebinding
##
## Stored as physical keycodes and joypad buttons per action, and **only for
## actions that have been changed** -- an empty `input` section means "whatever
## the project ships with", so a new binding added to the project reaches
## everybody who has not rebound that action. Storing the whole map would freeze
## every player's controls at the version they first ran.
class_name Settings
extends RefCounted

const PATH := "user://settings.json"
const FORMAT_VERSION := 1

## Window scales offered, as multiples of the 1920x1080 design resolution.
## Below 0.5 the HUD text stops being readable; above 1.0 needs a display that
## most people do not have, and fullscreen covers that case anyway.
const SCALES := [0.5, 0.75, 1.0]

## The actions a player may rebind, in the order the options screen lists them.
##
## Deliberately not every action in the map: `slide` is down+jump rather than a
## binding of its own (see the pause menu's control list), and the debug overlay
## is not a player-facing control.
## The sword's action is `melee`, not `sword`. That is worth a line: the pause
## menu's docstring records that `melee` spent two milestones bound in
## `project.godot` and missing from the generator that owns the bindings, and
## the first draft of this list guessed `sword` from the button's name on the
## controls screen. `test_every_rebindable_action_exists` caught it, which is
## the only reason it is not a dead row here.
const REBINDABLE: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"shoot", &"melee", &"weapon_prev", &"weapon_next", &"pause",
]

## InputMap's "any device" wildcard, and the one thing every event this class
## builds or accepts has to carry.
##
## **A binding pinned to a device number is a binding nothing can press.**
## `InputMap` matches an event only when the bound device is this wildcard or is
## exactly the device the press came from, and a freshly constructed
## `InputEvent` does not start here -- in Godot 4.7 `InputEventKey.new().device`
## is 16. Rebuilding the map from a settings file therefore silently re-pinned
## every action to a device no keyboard sends, which took the whole game with
## it: the title screen stopped answering, and the run could not be started.
##
## Worse than the same bug in the generator, because this one *persisted*. Any
## player who had ever opened this screen had an `input` section in their
## settings file, so the map was rebuilt this way on every launch and a fixed
## project.godot would not have reached them.
const ALL_DEVICES := -1

static var master := 1.0
static var music := 0.8
static var sfx := 1.0
static var scale := 1.0
static var fullscreen := false
## The redundant cue for the disappearing panels. See `apply_colourblind`.
static var colourblind := false

static var _loaded := false


## Reads the file and applies everything in it. Safe to call more than once.
static func load_settings() -> bool:
	_loaded = true
	if not FileAccess.file_exists(PATH):
		apply()
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		apply()
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		apply()
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != FORMAT_VERSION:
		# A settings file from another version is discarded rather than
		# half-read. Unlike a save, nothing is lost that the player cannot
		# redo in thirty seconds.
		apply()
		return false
	master = clampf(float(data.get("master", master)), 0.0, 1.0)
	music = clampf(float(data.get("music", music)), 0.0, 1.0)
	sfx = clampf(float(data.get("sfx", sfx)), 0.0, 1.0)
	scale = float(data.get("scale", scale))
	fullscreen = bool(data.get("fullscreen", fullscreen))
	colourblind = bool(data.get("colourblind", colourblind))
	_load_bindings(data.get("input", {}))
	apply()
	return true


static func save_settings() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Settings: could not write %s" % PATH)
		return false
	file.store_string(JSON.stringify({
		"version": FORMAT_VERSION,
		"master": master,
		"music": music,
		"sfx": sfx,
		"scale": scale,
		"fullscreen": fullscreen,
		"colourblind": colourblind,
		"input": _saved_bindings(),
	}, "\t"))
	file.close()
	return true


static func is_loaded() -> bool:
	return _loaded


## Pushes every setting at the engine. Called after a load and after any change,
## so there is one path from "the value changed" to "the game changed".
static func apply() -> void:
	apply_volume()
	apply_window()


static func apply_volume() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio := tree.root.get_node_or_null(^"AudioManager")
	if audio == null:
		return
	audio.set_volume(&"Master", master)
	audio.set_volume(&"Music", music)
	audio.set_volume(&"Sfx", sfx)
	# The jingle bus follows the music slider: they are the same kind of sound
	# to a player, and a separate control for "the fanfare" is a control nobody
	# wants and everybody has to read past.
	audio.set_volume(&"Jingle", music)


static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var wanted := Vector2i(int(1920.0 * scale), int(1080.0 * scale))
	DisplayServer.window_set_size(wanted)


## Nudges the scale up or down through `SCALES`, and returns the new one.
static func step_scale(delta: int) -> float:
	var index := SCALES.find(scale)
	if index < 0:
		index = SCALES.size() - 1
	scale = float(SCALES[clampi(index + delta, 0, SCALES.size() - 1)])
	return scale


# --- The colourblind cue ----------------------------------------------------------

## **The option adds a cue, it does not only change a colour.**
##
## docs/PLAN.md asks for "a colourblind palette for the disappearing-block
## gimmick", and a palette on its own is the weaker half of the answer. A player
## who cannot separate the panel's blue from the backdrop is helped by a
## different blue; a player who cannot separate *any* two hues is not helped by
## any palette at all. So the switch does both: a high-contrast pale panel
## against the dark mount, **and** a hatch across its face that the backdrop
## never has.
##
## Redundant encoding -- colour plus shape -- is the actual rule, and it costs
## one `if` in `PhaseBlock._draw`.
static func panel_colour(normal: Color) -> Color:
	return Color(0.96, 0.97, 1.0) if colourblind else normal


static func panel_hatched() -> bool:
	return colourblind


# --- Bindings ---------------------------------------------------------------------

## The events for an action, as the options screen shows them.
static func binding_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var parts: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			parts.append(OS.get_keycode_string(
				(event as InputEventKey).physical_keycode))
		elif event is InputEventJoypadButton:
			parts.append("PAD %d" % (event as InputEventJoypadButton).button_index)
	return " / ".join(parts) if not parts.is_empty() else "—"


## Replaces an action's keyboard binding, leaving its pad binding alone.
##
## **Keyboard only, deliberately.** A player rebinding on a keyboard has not
## asked to lose their controller, and the two are separate enough that one
## screen doing both would need a mode switch on every row.
static func rebind(action: StringName, event: InputEventKey) -> bool:
	if not InputMap.has_action(action) or event == null:
		return false
	var keep: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if not (existing is InputEventKey):
			keep.append(existing)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, _bindable(event))
	for existing in keep:
		InputMap.action_add_event(action, existing)
	return true


## Puts every rebindable action back to what the project ships with.
static func reset_bindings() -> void:
	for action in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event in ProjectSettings.get_setting("input/%s" % action,
				{}).get("events", []):
			InputMap.action_add_event(action, _bindable(event))


static func _saved_bindings() -> Dictionary:
	var out := {}
	for action in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		var keys: Array[int] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(int((event as InputEventKey).physical_keycode))
		if not keys.is_empty():
			out[String(action)] = keys
	return out


static func _load_bindings(stored: Variant) -> void:
	if not (stored is Dictionary):
		return
	for name: String in (stored as Dictionary):
		var action := StringName(name)
		if not InputMap.has_action(action):
			continue
		var keys: Variant = (stored as Dictionary)[name]
		if not (keys is Array) or (keys as Array).is_empty():
			continue
		var keep: Array[InputEvent] = []
		for existing in InputMap.action_get_events(action):
			if not (existing is InputEventKey):
				keep.append(existing)
		InputMap.action_erase_events(action)
		for code in (keys as Array):
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			event.device = ALL_DEVICES
			InputMap.action_add_event(action, event)
		for existing in keep:
			InputMap.action_add_event(action, existing)


## An event as the map should hold it: a copy that answers any device.
##
## A copy rather than a mutation because the event handed to `rebind` is the
## live one the options screen is still holding, and the events read back from
## `ProjectSettings` are shared with the project settings themselves. Both are
## someone else's to own.
static func _bindable(event: InputEvent) -> InputEvent:
	var copy := event.duplicate() as InputEvent
	copy.device = ALL_DEVICES
	return copy
