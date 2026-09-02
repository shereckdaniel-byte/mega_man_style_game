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

# action -> { keys, buttons, axes: [[axis, direction], ...] }
const BINDINGS := {
	&"move_left":   {"keys": [KEY_LEFT, KEY_A],  "buttons": [JOY_BUTTON_DPAD_LEFT],  "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	&"move_right":  {"keys": [KEY_RIGHT, KEY_D], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X,  1.0]]},
	&"move_up":     {"keys": [KEY_UP, KEY_W],    "buttons": [JOY_BUTTON_DPAD_UP],    "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	&"move_down":   {"keys": [KEY_DOWN, KEY_S],  "buttons": [JOY_BUTTON_DPAD_DOWN],  "axes": [[JOY_AXIS_LEFT_Y,  1.0]]},
	# Slide is deliberately not an action: it is move_down + jump, as in Mega Man 3.
	&"jump":        {"keys": [KEY_Z, KEY_SPACE], "buttons": [JOY_BUTTON_A]},
	&"shoot":       {"keys": [KEY_X],            "buttons": [JOY_BUTTON_X]},
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
			events.append(e)

		for button: int in spec.get("buttons", []):
			var e := InputEventJoypadButton.new()
			e.button_index = button
			events.append(e)

		for axis: Array in spec.get("axes", []):
			var e := InputEventJoypadMotion.new()
			e.axis = axis[0]
			e.axis_value = axis[1]
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
