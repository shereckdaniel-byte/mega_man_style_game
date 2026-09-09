## Every sound the game can make, by the name of the thing that makes it.
##
## **A name, not a path, at every call site.** `Sfx.play(&"jump")` rather than a
## `preload` of a `.wav`: the sounds are generated (see `tools/make_sfx.gd`), so
## the set of them changes, and a rename that broke fifty call sites would mean
## the audio never got renamed. `tests/test_audio.gd` holds the two halves
## together -- every name this class knows has a file, and every file has a name.
##
## **Missing files are not an error.** A sound that has not been made yet plays
## nothing and the game continues, because the alternative is that the whole
## project stops working the day somebody deletes a `.wav`. What *is* an error is
## a name nobody ever plays, or a file nobody ever asks for, and that is what the
## test is for -- silence is caught at build time rather than in a living room.
class_name Sfx
extends RefCounted

const DIR := "res://assets/audio/sfx"

## Cached streams. A pickup can fire several times a second and `load` on the
## frame is how a game gets a hitch on the one frame the player is happiest.
static var _cache: Dictionary = {}


## The stream for an event, or null if there is no file for it.
static func stream(event: StringName) -> AudioStream:
	if _cache.has(event):
		return _cache[event]
	var path := "%s/%s.wav" % [DIR, event]
	var found: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[event] = found
	return found


## Plays an event. Safe to call from anywhere, including from a node that is
## about to be freed and from a headless test with no audio device.
static func play(event: StringName, volume_db := 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio := tree.root.get_node_or_null(^"AudioManager")
	if audio == null:
		return
	audio.play_sfx(stream(event), volume_db)


## Every event name on disk. Read from the directory rather than listed, for the
## same reason the weapon catalogue is: a list in code is a list that goes stale.
static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for file in files:
		var name := file.trim_suffix(".remap")
		if name.ends_with(".wav"):
			out.append(StringName(name.get_basename()))
	return out


static func has(event: StringName) -> bool:
	return stream(event) != null


## The sound a weapon makes when it fires.
##
## **By archetype, not by weapon.** The eight are deliberately a family -- same
## envelope, same length, different timbre and direction -- so a player learns
## "that is a weapon" before they learn which one, exactly as the eight
## projectiles are eight readings of one idea. Eight separate sounds authored
## per weapon would drift into eight unrelated noises.
##
## The mapping is here rather than on `WeaponData` because it is a property of
## the *archetype* (docs/PLAN.md section 4's table), and a weapon resource
## already says which archetype it is by which projectile it carries.
const WEAPON_SOUNDS := {
	&"buster": &"shoot",
	&"cinder_spray": &"weapon_spread",
	&"arc_lance": &"weapon_homing",
	&"prism_ray": &"weapon_beam",
	&"rust_bloom": &"weapon_arc",
	&"quarry_bore": &"weapon_pierce",
	&"tide_crawler": &"weapon_crawl",
	&"frost_lock": &"weapon_stun",
	&"gale_cutter": &"weapon_throw",
	# The dog's three summon rather than shoot, and a summon is a teleport.
	&"rush_coil": &"teleport_pad",
	&"rush_jet": &"teleport_pad",
	&"rush_marine": &"teleport_pad",
}


static func for_weapon(weapon_id: StringName) -> StringName:
	return WEAPON_SOUNDS.get(weapon_id, &"shoot")
