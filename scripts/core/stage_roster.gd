## The eight stages, in one place.
##
## docs/PLAN.md section 4 is the design; this is the same table in a form the
## game can read. It existed in three partial copies before — the stage select
## needs name, portrait and scene; `tools/playthrough.gd` needs name and scene;
## each stage script knows only its own boss — and a roster kept in three places
## is a roster that disagrees in two of them the first time a stage is renamed.
##
## **`scene` empty means the stage is not built.** That is a first-class state
## rather than an omission: six of the eight are unbuilt today, the select screen
## has to show them as coming rather than pretend they are not in the game, and
## the alternative — listing only what exists — makes the screen silently change
## shape as stages land, which is exactly when a 3×3 grid should not move.
class_name StageRoster


## Boss index -> the stage that boss owns. Index is the bit position in
## `GameState.bosses_defeated`, so these must not be reordered.
const ENTRIES := [
	{
		"index": 0, "boss": "Tide", "stage": "Dawn Boardwalk",
		"weapon": "Tide Crawler",
		"frames": "res://resources/sprite_frames/wave_man.tres",
		"scene": "res://scenes/stages/dawn_boardwalk/dawn_boardwalk.tscn",
	},
	{
		"index": 1, "boss": "Arc", "stage": "Substation",
		"weapon": "Arc Lance",
		"frames": "res://resources/sprite_frames/arc.tres",
		"scene": "res://scenes/stages/substation/substation.tscn",
	},
	{
		"index": 2, "boss": "Rust", "stage": "Breakers",
		"weapon": "Rust Bloom",
		"frames": "res://resources/sprite_frames/rust.tres",
		"scene": "res://scenes/stages/breakers/breakers.tscn",
	},
	{
		"index": 3, "boss": "Prism", "stage": "Mirror Field",
		"weapon": "Prism Ray",
		"frames": "res://resources/sprite_frames/prism.tres",
		"scene": "",
	},
	{
		"index": 4, "boss": "Gale", "stage": "Turbine Row",
		"weapon": "Gale Cutter",
		"frames": "res://resources/sprite_frames/gale.tres",
		"scene": "",
	},
	{
		"index": 5, "boss": "Cinder", "stage": "Stack",
		"weapon": "Cinder Spray",
		"frames": "res://resources/sprite_frames/cinder.tres",
		"scene": "",
	},
	{
		"index": 6, "boss": "Frost", "stage": "Cold Store",
		"weapon": "Frost Lock",
		"frames": "res://resources/sprite_frames/frost.tres",
		"scene": "",
	},
	{
		"index": 7, "boss": "Quarry", "stage": "Sinkhole",
		"weapon": "Quarry Bore",
		"frames": "res://resources/sprite_frames/quarry.tres",
		"scene": "",
	},
]

## Where each boss sits on the 3x3 grid, by index. The centre is not a boss --
## in the original it holds the player, and here it is the fortress slot that
## M7 unlocks.
##
##     0 1 2
##     3 . 4
##     5 6 7
const GRID := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1),                 Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
]
const CENTRE := Vector2i(1, 1)


static func entry(index: int) -> Dictionary:
	return ENTRIES[index] if index >= 0 and index < ENTRIES.size() else {}


static func is_built(index: int) -> bool:
	var row := entry(index)
	if row.is_empty():
		return false
	var path: String = row["scene"]
	return not path.is_empty() and ResourceLoader.exists(path)


## The indices of every stage that can actually be entered today.
static func built() -> Array[int]:
	var out: Array[int] = []
	for row in ENTRIES:
		if is_built(int(row["index"])):
			out.append(int(row["index"]))
	return out


static func grid_position(index: int) -> Vector2i:
	return GRID[index] if index >= 0 and index < GRID.size() else CENTRE


## The boss index at a grid cell, or -1 for the centre and anything off it.
static func at(cell: Vector2i) -> int:
	for i in GRID.size():
		if GRID[i] == cell:
			return i
	return -1
