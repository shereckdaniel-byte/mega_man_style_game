## Builds every piece of music in the game.
##
##   godot --headless --script res://tools/make_music.gd
##
## **A theme is a line of note numbers, not a file.** Same argument as the sound
## effects: a `.wav` in a repository cannot be read, argued with, or transposed.
## These can. Each track is three voices -- two pulses and a triangle bass, which
## is what the hardware had -- written as strings of semitones where `.` holds
## the previous note and `-` is a rest.
##
## **What this is and is not.** It is eight stage themes and six jingles, in
## key, in time, and built from the same synthesiser as everything else, so the
## game is never silent and the audio system is exercised end to end by real
## content. It is not a composed soundtrack: nobody on this project can write
## one, and a loop that states a hook and gets out of the way is the honest
## version of what a placeholder should be. Every one of them is a candidate for
## replacement by a person, and the format is deliberately the easiest thing in
## the repository to replace -- delete the row, drop in a file.
##
## Development tool: not referenced by the game.
extends SceneTree

const OUT := "res://assets/audio/music"

## Sixteenth notes per minute, expressed as the length of one step. 0.125 is
## 120 BPM in eighths, which is the tempo almost every NES stage theme sits at.
const STEP := 0.125

const THIN := 0.125
const REED := 0.25
const HOLLOW := 0.5

## Scale degrees, so a melody can be written in a key rather than in semitones
## and still be read by somebody who does not count in twelves.
const A_MINOR := [69, 71, 72, 74, 76, 77, 79, 81]
const D_MINOR := [62, 64, 65, 67, 69, 70, 72, 74]
const E_MINOR := [64, 66, 67, 69, 71, 72, 74, 76]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for name in _tracks():
		var spec: Dictionary = _tracks()[name]
		var synth := _render(spec)
		synth.normalise(0.72)
		var loop := bool(spec.get("loop", true))
		if not loop:
			synth.fade_out(0.08)
		var path := "%s/%s.wav" % [OUT, name]
		if synth.save(ProjectSettings.globalize_path(path), loop) != OK:
			printerr("could not write %s" % path)
			quit(1)
			return
		made += 1
		print("%-18s %5.2fs  %s" % [name, synth.length_seconds(),
			"loop" if loop else "once"])
	print("%d tracks -> %s" % [made, OUT])
	quit(0)


## Renders one track. `lead` and `harmony` are pulses, `bass` is the triangle.
func _render(spec: Dictionary) -> Synth:
	var synth := Synth.new()
	var scale: Array = spec.get("scale", A_MINOR)
	var step := float(spec.get("step", STEP))
	_voice(synth, String(spec.get("lead", "")), scale, step,
		float(spec.get("lead_octave", 0.0)), REED, 0.42,
		Synth.Env.new(0.004, 0.05, 0.55, 0.03))
	_voice(synth, String(spec.get("harmony", "")), scale, step,
		float(spec.get("harmony_octave", -12.0)), THIN, 0.24,
		Synth.Env.new(0.006, 0.06, 0.45, 0.03))
	_bass(synth, String(spec.get("bass", "")), scale, step,
		float(spec.get("bass_octave", -24.0)))
	_drums(synth, String(spec.get("drums", "")), step)
	return synth


## One pulse voice. The pattern is space-separated tokens: a scale degree
## (`1`-`8`, with `+` for an octave up), `.` to hold, or `-` to rest.
func _voice(synth: Synth, pattern: String, scale: Array, step: float,
		octave: float, duty: float, gain: float, env: Synth.Env) -> void:
	if pattern.is_empty():
		return
	var tokens := pattern.split(" ", false)
	var i := 0
	while i < tokens.size():
		var token := String(tokens[i])
		if token == "-" or token == ".":
			i += 1
			continue
		# A note runs until the next token that is not a hold, so `1 . . .` is a
		# held note rather than four attacks -- which is what makes a melody
		# readable as phrasing rather than as a machine gun.
		var held := 1
		while i + held < tokens.size() and String(tokens[i + held]) == ".":
			held += 1
		var note := _note(token, scale) + octave
		synth.pulse(float(i) * step, float(held) * step * 0.98,
			Synth.hz(note), Synth.hz(note), duty, gain, env)
		i += held


func _bass(synth: Synth, pattern: String, scale: Array, step: float,
		octave: float) -> void:
	if pattern.is_empty():
		return
	var tokens := pattern.split(" ", false)
	var env := Synth.Env.new(0.006, 0.08, 0.6, 0.04)
	var i := 0
	while i < tokens.size():
		var token := String(tokens[i])
		if token == "-" or token == ".":
			i += 1
			continue
		var held := 1
		while i + held < tokens.size() and String(tokens[i + held]) == ".":
			held += 1
		var note := _note(token, scale) + octave
		synth.triangle(float(i) * step, float(held) * step * 0.98,
			Synth.hz(note), Synth.hz(note), 0.55, env)
		i += held


## `x` is a kick, `s` a snare, `h` a hat, anything else a rest. Noise only,
## which is all the chip had and all this needs.
func _drums(synth: Synth, pattern: String, step: float) -> void:
	if pattern.is_empty():
		return
	for i in pattern.length():
		var at := float(i) * step
		match pattern[i]:
			"x":
				synth.noise(at, step * 0.9, 140, 0.30,
					Synth.Env.new(0.001, 0.05, 0.2, 0.04), i + 1)
			"s":
				synth.noise(at, step * 0.8, 22, 0.26,
					Synth.Env.new(0.001, 0.04, 0.2, 0.03), i + 7)
			"h":
				synth.noise(at, step * 0.4, 5, 0.12,
					Synth.Env.new(0.001, 0.02, 0.1, 0.02), i + 13)


func _note(token: String, scale: Array) -> float:
	var up := 0.0
	var text := token
	while text.ends_with("+"):
		up += 12.0
		text = text.substr(0, text.length() - 1)
	while text.ends_with("_"):
		up -= 12.0
		text = text.substr(0, text.length() - 1)
	var degree := clampi(int(text), 1, scale.size()) - 1
	return float(scale[degree]) + up


## The tracks. Eight stage themes, and the six jingles the milestone asks for.
func _tracks() -> Dictionary:
	return {
		# --- Stage themes -----------------------------------------------------
		# Each one is sixteen steps of two bars, chosen to sit under play rather
		# than over it. The differences between them are deliberate and small:
		# key, tempo, and how busy the bass is.
		"dawn_boardwalk": {
			"scale": D_MINOR, "step": 0.135,
			"lead":    "1 . 3 . 5 . 3 . 4 . 3 . 1 . . .",
			"harmony": "5 . 5 . 8 . 8 . 6 . 6 . 5 . . .",
			"bass":    "1 . . . 5 . . . 4 . . . 5 . . .",
			"drums":   "x h s h x h s h x h s h x h s s",
		},
		"substation": {
			"scale": E_MINOR, "step": 0.115,
			"lead":    "1 2 3 . 5 4 3 . 2 3 4 . 3 . . .",
			"harmony": "- - 8 . - - 6 . - - 5 . 4 . . .",
			"bass":    "1 . 1 . 3 . 3 . 2 . 2 . 5 . . .",
			"drums":   "x h h s x h h s x h h s x s x s",
		},
		"breakers": {
			"scale": A_MINOR, "step": 0.125,
			"lead":    "1 . 1 . 4 . 4 . 3 . 3 . 5 . . .",
			"harmony": "3 . 3 . 6 . 6 . 5 . 5 . 8 . . .",
			"bass":    "1 1 . . 4 4 . . 3 3 . . 5 5 . .",
			"drums":   "x s x s x s x s x s x s x x s s",
		},
		"mirror_field": {
			"scale": A_MINOR, "step": 0.105,
			"lead":    "8 . 7 . 6 . 5 . 6 . 7 . 8 . . .",
			"harmony": "5 . 4 . 3 . 2 . 3 . 4 . 5 . . .",
			"bass":    "1 . . . 6_ . . . 4_ . . . 5_ . . .",
			"drums":   "h h h h h h h h h h h h h h s s",
		},
		"turbine_row": {
			"scale": E_MINOR, "step": 0.110,
			"lead":    "5 . 6 . 8 . 6 . 5 . 4 . 3 . . .",
			"harmony": "1 . 1 . 3 . 3 . 1 . 1 . 8_ . . .",
			"bass":    "1 . 5_ . 1 . 5_ . 4_ . 1 . 5_ . . .",
			"drums":   "x h s h x h s h x h s h s s x .",
		},
		"stack": {
			"scale": D_MINOR, "step": 0.100,
			"lead":    "1 3 5 3 1 3 5 3 4 6 8 6 5 . . .",
			"harmony": "- - 8 . - - 8 . - - 6 . 5 . . .",
			"bass":    "1 . 1 1 . 1 . 1 4 . 4 . 5 . . .",
			"drums":   "x s h s x s h s x s h s x x s s",
		},
		"cold_store": {
			"scale": A_MINOR, "step": 0.145,
			"lead":    "8 . . . 5 . . . 6 . . . 5 . . .",
			"harmony": "3 . . . 1 . . . 2 . . . 1 . . .",
			"bass":    "1 . . . . . . . 4_ . . . . . . .",
			"drums":   "h . . . h . . . h . . . h . s .",
		},
		"sinkhole": {
			"scale": D_MINOR, "step": 0.130,
			"lead":    "1 . 2 . 3 . 2 . 1 . 8_ . 1 . . .",
			"harmony": "5 . 6 . 8 . 6 . 5 . 4 . 5 . . .",
			"bass":    "1 . . 1 . . 4_ . . . 5_ . . . 1 .",
			"drums":   "x . s . x . s . x . s . x s x s",
		},

		# --- The fortress -----------------------------------------------------
		# One theme for all four, as they share one backdrop and one place.
		"fortress": {
			"scale": A_MINOR, "step": 0.095,
			"lead":    "1 . 8_ . 1 . 2 . 1 . 8_ . 5_ . . .",
			"harmony": "5 . 4 . 5 . 6 . 5 . 4 . 3 . . .",
			"bass":    "1 1 1 1 1 1 1 1 4_ 4_ 4_ 4_ 5_ 5_ 5_ 5_",
			"drums":   "x s x s x s x s x s x s x x s s",
		},

		# --- Jingles ----------------------------------------------------------
		# Six, as the milestone asks. None of them loops: a jingle that looped
		# would be a theme.
		"jingle_stage_select": {
			"scale": A_MINOR, "step": 0.130, "loop": true,
			"lead":    "1 . 3 . 5 . 8 . 5 . 3 . 1 . . .",
			"harmony": "- . 1 . 3 . 5 . 3 . 1 . 5_ . . .",
			"bass":    "1 . . . 4_ . . . 5_ . . . 1 . . .",
			"drums":   "h . h . h . h . h . h . h . s .",
		},
		"jingle_weapon_get": {
			"scale": A_MINOR, "step": 0.115, "loop": false,
			"lead":    "1 3 5 8 5 8 + . . . 8 . . . . .",
			"harmony": "- - 1 3 1 3 5 . . . 5 . . . . .",
			"bass":    "1 . 1 . 1 . 1 . . . 1 . . . . .",
			"drums":   "x . x . x . x s . . x . . . . .",
		},
		"jingle_boss_defeated": {
			"scale": A_MINOR, "step": 0.120, "loop": false,
			"lead":    "8 . 5 . 3 . 1 . . . . . . . . .",
			"harmony": "5 . 3 . 1 . 5_ . . . . . . . . .",
			"bass":    "1 . . . . . 1 . . . . . . . . .",
			"drums":   "x . s . x . x s . . . . . . . .",
		},
		"jingle_game_over": {
			"scale": D_MINOR, "step": 0.170, "loop": false,
			"lead":    "5 . 4 . 3 . 2 . 1 . . . . . . .",
			"harmony": "3 . 2 . 1 . 8_ . 5_ . . . . . . .",
			"bass":    "1 . . . 5_ . . . 1_ . . . . . . .",
			"drums":   "x . . . s . . . x . . . . . . .",
		},
		"jingle_checkpoint": {
			"scale": A_MINOR, "step": 0.090, "loop": false,
			"lead":    "5 8 + . . . . . . . . . . . . .",
			"harmony": "1 3 5 . . . . . . . . . . . . .",
			"bass":    "",
			"drums":   "h . h . . . . . . . . . . . . .",
		},
		"jingle_ending": {
			"scale": D_MINOR, "step": 0.150, "loop": true,
			"lead":    "1 . 5 . 8 . 5 . 6 . 5 . 3 . 1 .",
			"harmony": "5_ . 1 . 3 . 1 . 4 . 3 . 1 . 5_ .",
			"bass":    "1 . . . 5_ . . . 4_ . . . 1 . . .",
			"drums":   "x . h . s . h . x . h . s . x .",
		},
	}
