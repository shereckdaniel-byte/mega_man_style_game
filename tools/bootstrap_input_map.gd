## Regenerates the [input] section of project.godot from the table in
## docs/ARCHITECTURE.md section 6.
##
## Hand-writing InputMap entries into project.godot means hand-writing Godot's
## Object(...) serialisation, which is verbose and changes between versions.
## Building them through the API and letting ProjectSettings.save() serialise is
## version-proof, and this file doubles as the readable record of the bindings.
##
##   godot --headless --script res://tools/bootstrap_input_map.gd
extends SceneTree

const DEADZONE := 0.5

## **Every event has to say "any device" out loud, or the keyboard does nothing.**
##
## `InputMap` only matches an event whose device is `-1` (its wildcard) or is
## exactly the device the press came from. A freshly constructed `InputEvent`
## does *not* start at `-1` -- in Godot 4.7 `InputEventKey.new().device` is 16 --
## so leaving the default in place pinned every generated binding to a device
## number no real keyboard ever sends. The bindings looked correct in
## project.godot and in the editor, `InputMap.has_action()` was true for all of
## them, and not one key press matched: the title screen took arrows and Z and
## answered with nothing, and the game could not be left.
##
## Named rather than a bare `-1` because the value is the whole point, and the
## engine does not expose `InputMap::ALL_DEVICES` to scripts to name it for us.
const ALL_DEVICES := -1

## **Re-running this drops any project setting that equals its engine default.**
## `ProjectSettings.save()` writes only what differs, so the explicit
## `rendering/textures/canvas_textures/default_texture_filter=1` line disappears
## -- Linear *is* the Godot 4 default, so nothing changes behaviourally and the
## settings tests still pass. What is lost is the declaration that Linear was a
## decision (SPRITES section 7 reversed it from Nearest), which is worth knowing
## before wondering where the line went.

# action -> { keys, buttons, axes: [[axis, direction], ...] }
const BINDINGS := {
	&"move_left":   {"keys": [KEY_LEFT, KEY_A],  "buttons": [JOY_BUTTON_DPAD_LEFT],  "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	&"move_right":  {"keys": [KEY_RIGHT, KEY_D], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X,  1.0]]},
	&"move_up":     {"keys": [KEY_UP, KEY_W],    "buttons": [JOY_BUTTON_DPAD_UP],    "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	&"move_down":   {"keys": [KEY_DOWN, KEY_S],  "buttons": [JOY_BUTTON_DPAD_DOWN],  "axes": [[JOY_AXIS_LEFT_Y,  1.0]]},
	# Slide is deliberately not an action: it is move_down + jump, as in Mega Man 3.
	&"jump":        {"keys": [KEY_Z, KEY_SPACE], "buttons": [JOY_BUTTON_A]},
	&"shoot":       {"keys": [KEY_X],            "buttons": [JOY_BUTTON_X]},
	# The sword. It was bound directly in project.godot when it was added and
	# never entered here, so for two milestones it existed in the generated file
	# and in no generator -- working, and owned by nothing. Re-running this tool
	# left it alone rather than deleting it, which is why nothing noticed.
	&"melee":       {"keys": [KEY_C],            "buttons": [JOY_BUTTON_Y]},
	&"weapon_prev": {"keys": [KEY_Q],            "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	&"weapon_next": {"keys": [KEY_E],            "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	&"pause":       {"keys": [KEY_ENTER, KEY_ESCAPE], "buttons": [JOY_BUTTON_START]},
	&"debug_overlay": {"keys": [KEY_F3], "buttons": []},
}


func _init() -> void:
	for action: StringName in BINDINGS:
		var spec: Dictionary = BINDINGS[action]
		var events: Array[InputEvent] = []

		for key: int in spec.get("keys", []):
			var e := InputEventKey.new()
			e.physical_keycode = key       # physical: same position on any layout
			e.device = ALL_DEVICES
			events.append(e)

		for button: int in spec.get("buttons", []):
			var e := InputEventJoypadButton.new()
			e.button_index = button
			# Pad 2 is as valid as pad 1; the old default bound player input to
			# whichever pad happened to enumerate first.
			e.device = ALL_DEVICES
			events.append(e)

		for axis: Array in spec.get("axes", []):
			var e := InputEventJoypadMotion.new()
			e.axis = axis[0]
			e.axis_value = axis[1]
			e.device = ALL_DEVICES
			events.append(e)

		ProjectSettings.set_setting("input/%s" % action, {
			"deadzone": DEADZONE,
			"events": events,
		})

	var err := ProjectSettings.save()
	if err != OK:
		push_error("Failed to save project.godot: %d" % err)
		quit(1)
		return
	print("Wrote %d input actions to project.godot" % BINDINGS.size())
	quit(0)
