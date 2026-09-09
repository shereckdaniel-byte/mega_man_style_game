## The audio: the buses, the catalogue, and the thing that actually goes wrong.
##
## **Silence does not fail.** Every other subsystem in this project announces a
## mistake -- a missing scene errors, a bad table fails a rule, a broken stage
## strands the bot. Audio just does not play, and nobody notices for a milestone.
## Both halves of the catalogue are therefore checked against each other: every
## name the game asks for has a file, and every file has somebody asking for it.
extends TestCase

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"

## Every source file that might play something, so "who asks for this" can be
## answered by reading the project rather than by keeping a list.
const CODE_DIRS := ["res://scenes", "res://scripts", "res://tools"]


# --- The buses ---------------------------------------------------------------------

## Four buses, and the layout is loaded. Without it every `bus = &"Music"` falls
## back to Master, the ducking does nothing, and the options screen's sliders
## move a volume nobody hears.
func test_the_bus_layout_is_loaded() -> void:
	for bus in [&"Master", &"Music", &"Sfx", &"Jingle"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0,
			"there is no %s bus; the layout did not load" % bus)


## **Music ducks under Jingle**, and it does it with a sidechained compressor
## rather than a tween. A tween that lowers the volume has to remember to put it
## back, and one interrupted by a scene change leaves the music quiet for the
## rest of the run -- a bug nobody reports because it does not look like one.
func test_the_music_bus_ducks_to_the_jingle_bus() -> void:
	var music := AudioServer.get_bus_index(&"Music")
	assert_true(music >= 0)
	var found: AudioEffectCompressor = null
	for i in AudioServer.get_bus_effect_count(music):
		var effect := AudioServer.get_bus_effect(music, i)
		if effect is AudioEffectCompressor:
			found = effect as AudioEffectCompressor
	assert_not_null(found, "the Music bus has no compressor on it")
	if found == null:
		return
	assert_eq(String(found.sidechain), "Jingle",
		"the compressor is keyed to %s rather than the jingle bus" % found.sidechain)
	assert_true(found.ratio >= 4.0,
		"a ratio of %.1f is not ducking, it is a suggestion" % found.ratio)


## Everything routes to Master, so one volume control reaches all of it.
func test_every_bus_reaches_master() -> void:
	for bus in [&"Music", &"Sfx", &"Jingle"]:
		var index := AudioServer.get_bus_index(bus)
		assert_eq(String(AudioServer.get_bus_send(index)), "Master",
			"%s sends to %s" % [bus, AudioServer.get_bus_send(index)])


# --- The catalogue -------------------------------------------------------------------

func test_there_are_sounds_and_music_on_disk() -> void:
	assert_true(Sfx.names().size() >= 40,
		"only %d sound effects" % Sfx.names().size())
	assert_true(Music.names().size() >= 14,
		"only %d tracks" % Music.names().size())


## Every file loads as audio. A `.wav` the importer choked on is a silent sound
## that is present, which is the hardest kind to notice.
func test_every_sound_loads() -> void:
	for name in Sfx.names():
		assert_not_null(Sfx.stream(name), "%s did not load" % name)
	for name in Music.names():
		assert_not_null(Music.stream(name), "%s did not load" % name)


## **Every name the code plays exists.** A typo in `Sfx.play(&"jmup")` is silent
## and permanent otherwise.
func test_every_sound_the_code_asks_for_exists() -> void:
	var asked := _asked_for("Sfx.play(&\"")
	assert_true(asked.size() >= 15,
		"only %d call sites found; the scan is not working" % asked.size())
	for name in asked:
		assert_true(Sfx.has(name),
			"something plays \"%s\" and there is no such sound" % name)


## And every track the code plays exists, the same way.
func test_every_track_the_code_asks_for_exists() -> void:
	var asked := _asked_for("Music.play(&\"")
	asked.append_array(_asked_for("Music.jingle(&\""))
	for name in asked:
		# A stage asks for its own folder name, which is resolved at runtime and
		# cannot be read out of the source -- those are covered by the stage
		# test below instead.
		assert_not_null(Music.stream(name),
			"something plays the track \"%s\" and there is no such file" % name)


## **Every stage has a theme**, which is the half a literal scan cannot check:
## `AuthoredStage.music_track` derives the name from the scene's own folder, so
## a stage whose `.wav` is missing plays nothing and says nothing.
func test_every_stage_has_music() -> void:
	for row in StageRoster.ENTRIES:
		var folder := String(row["scene"]).get_base_dir().get_file()
		assert_not_null(Music.stream(StringName(folder)),
			"%s has no theme (%s.wav)" % [row["stage"], folder])
	# The four fortress stages share one, which is why they are not in the loop.
	assert_not_null(Music.stream(&"fortress"), "the fortress has no theme")


## The six jingles the milestone asks for, by name, because each one is a moment
## somebody decided deserved music and a missing one is a moment gone quiet.
func test_the_jingles_are_all_here() -> void:
	for name in [&"jingle_stage_select", &"jingle_weapon_get",
			&"jingle_boss_defeated", &"jingle_game_over", &"jingle_checkpoint",
			&"jingle_ending"]:
		assert_not_null(Music.stream(name), "no %s" % name)


## **Nothing on disk is unreferenced.** A sound nobody plays is either a missing
## call site or dead weight in the repository, and both are worth knowing.
##
## Any mention counts, not just a `play` next to it: a pickup chooses its chime
## from its kind and a weapon chooses its shot from its archetype, and in both
## cases the name is a literal in the source. What this catches is a `.wav`
## nothing anywhere refers to.
func test_every_sound_on_disk_is_played_by_something() -> void:
	var asked := _mentioned()
	var orphans: Array[String] = []
	for name in Sfx.names():
		if not asked.has(name):
			orphans.append(String(name))
	assert_eq(orphans.size(), 0,
		"nothing ever plays: %s" % ", ".join(orphans))


# --- Volume ------------------------------------------------------------------------

## The options screen works in 0..1 because that is what a slider is; decibels
## are the engine's unit and nobody else's.
func test_volume_round_trips_in_linear() -> void:
	var audio := tree.root.get_node_or_null(^"AudioManager")
	if audio == null:
		return
	var was: float = audio.get_volume(&"Sfx")
	for wanted in [1.0, 0.5, 0.25]:
		audio.set_volume(&"Sfx", wanted)
		assert_almost_eq(float(audio.get_volume(&"Sfx")), wanted, 0.02,
			"set %.2f and got %.2f" % [wanted, audio.get_volume(&"Sfx")])
	# Zero is mute rather than a very small number, so a muted game is silent
	# rather than nearly silent.
	audio.set_volume(&"Sfx", 0.0)
	assert_eq(float(audio.get_volume(&"Sfx")), 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Sfx")))
	audio.set_volume(&"Sfx", was)


# --- Plumbing ----------------------------------------------------------------------

## Every name passed to a call like `Sfx.play(&"jump")` anywhere in the project.
##
## Literal call sites only. Sounds chosen at runtime -- a pickup picking its
## chime from its kind, a weapon picking its shot from its archetype -- are
## covered by `_mentioned` instead, because the name is still written down in
## the source, just not next to `play`.
func _asked_for(prefix: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for dir in CODE_DIRS:
		_scan(dir, prefix, out)
	return out


func _scan(path: String, prefix: String, into: Array[StringName]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for folder in dir.get_directories():
		_scan(path.path_join(folder), prefix, into)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(path.path_join(file))
		var from := 0
		while true:
			var at := text.find(prefix, from)
			if at < 0:
				break
			var start := at + prefix.length()
			var end := text.find("\"", start)
			if end < 0:
				break
			var name := StringName(text.substr(start, end - start))
			if not into.has(name):
				into.append(name)
			from = end


## Every sound name written anywhere in the project's source, however it is
## used. `&"jump"` in a match arm counts as much as `Sfx.play(&"jump")`.
func _mentioned() -> Dictionary:
	var out := {}
	for name in Sfx.names():
		var needle := "&\"%s\"" % name
		for dir in CODE_DIRS:
			if _contains(dir, needle):
				out[name] = true
				break
	return out


func _contains(path: String, needle: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	for folder in dir.get_directories():
		if _contains(path.path_join(folder), needle):
			return true
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		if FileAccess.get_file_as_string(path.path_join(file)).contains(needle):
			return true
	return false
