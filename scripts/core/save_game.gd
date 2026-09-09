## The save slot: the other half of docs/ARCHITECTURE.md section 8.
##
## Writes the same struct the password packs -- `GameState.to_dict` -- as JSON
## at `user://save_0.json`. Static rather than an autoload, because it holds no
## state of its own: it is a pair of functions over a path, and an autoload
## would be a singleton whose only job is to not be one.
##
## ### What a save has that a password does not
##
## **Lives**, and that is the whole difference in kind. A password is a way back
## into a run and must not carry a resource the player can farm; a save is a
## pause in one, so putting it down and picking it up should not cost anything.
## `Password` refuses lives for exactly the reason this keeps them.
##
## ### Every read is defensive, and none of them throws
##
## A save file is the one input this game takes from outside itself, and it can
## be missing, truncated, hand-edited, or written by a build with different
## fields. Every one of those has to end as "no save" or "a save with sensible
## values", never as a crash on the title screen or a run that starts with
## minus four lives. `read` returns an empty dictionary for anything it cannot
## trust and `GameState.from_dict` clamps what it is given.
class_name SaveGame

## Where slots live. `user://` is the per-user data directory Godot resolves per
## platform, which is the only writable place an exported build has.
const SLOT_PATH := "user://save_%d.json"
## How many slots the game offers. One, for now, and named as a constant so the
## screens that will offer more do not have to guess.
const SLOT_COUNT := 1

## Bumped when the shape of the struct changes, so a save from an older build is
## refused rather than half-read. It is cheaper to ask a player to start again
## than to load four of six fields and leave the rest at whatever the last run
## happened to set them to.
const FORMAT_VERSION := 1


static func path(slot: int) -> String:
	return SLOT_PATH % maxi(slot, 0)


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## Writes progress. Returns false if the file could not be opened, which a
## caller should surface rather than swallow -- a save that silently did not
## happen is worse than one that visibly failed.
static func write(slot: int, state: Dictionary) -> bool:
	var payload := state.duplicate(true)
	payload["version"] = FORMAT_VERSION
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_error("save: could not open %s for writing (%d)"
			% [path(slot), FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## Reads progress, or an empty dictionary when there is nothing trustworthy
## there. See the note on defensiveness -- this never pushes an error for a
## missing file, because "no save yet" is the normal state on a first run.
static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var file := FileAccess.open(path(slot), FileAccess.READ)
	if file == null:
		push_error("save: could not open %s for reading" % path(slot))
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("save: %s is not a JSON object" % path(slot))
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != FORMAT_VERSION:
		push_error("save: %s is version %s, this build writes %d"
			% [path(slot), data.get("version", "none"), FORMAT_VERSION])
		return {}
	# The version is bookkeeping and not progress; handing it on would put a
	# stray key into GameState's struct.
	data.erase("version")
	return data


## Deletes a slot. True if there is no file there afterwards, which is the
## question a caller actually has -- erasing a slot that was already empty is a
## success, not a failure.
static func erase(slot: int) -> bool:
	if not exists(slot):
		return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))
	if error != OK:
		push_error("save: could not remove %s (%d)" % [path(slot), error])
	return not exists(slot)
