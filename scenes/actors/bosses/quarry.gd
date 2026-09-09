## Quarry -- Sinkhole's Robot Master, and the last of the eight.
##
## Twenty-one answers are spent by boss eight. Cinder's three were the last new
## verbs and Frost escalated the *structure* instead by making its patterns
## compose. Quarry escalates the **arena**: it is the only boss in the roster
## that changes the room it is fighting in, and all three of its patterns are
## about the floor rather than about the air above it.
##
##   * **Bore** comes up **through the deck**. It is the only attack in the game
##     that arrives from below, and the tell is a crack in the ground at the far
##     end of the arena -- so the answer is **to look away from the boss**.
##     Every other telegraph in the roster is on the thing that is going to hurt
##     you; this one is on the ground you are standing on, and you cannot watch
##     both. It is also too tall to jump, so reading it late is not an option.
##   * **Flood** raises water over the arena floor for a while. Nothing about it
##     damages. What it does is **change the player's jump mid-fight** -- three
##     times the apex, a much slower fall -- so every distance the player has
##     spent the whole stage learning is briefly wrong. The answer is to
##     re-aim, and it is the only pattern in the game whose answer is a
##     recalibration rather than a move.
##   * **Cave-In** brings the roof down, and **the rubble stays as platforms**.
##     It is the only boss attack in the game that leaves the player something.
##     The debris is in the way and it is also the only height in the room, and
##     since the Bore cannot be jumped from the floor, deciding which of those
##     the rubble is this time is the fight.
##
## Looking away, recalibrating, and using the wreckage. All three are about the
## room; none of them is a dodge.
##
## ### The chain closes here
##
## Quarry is weak to Cinder Spray and drops Quarry Bore, which Frost is weak to.
## With this boss the 3-cycle (Cinder -> Frost -> Quarry -> Cinder) and the
## 5-cycle (Tide -> Arc -> Rust -> Prism -> Gale -> Tide) are both complete, no
## boss is weak to the weapon it drops, and every one of PLAN.md's eight weapon
## archetypes is used exactly once. `tests/test_quarry.gd` checks the whole
## chain rather than this paragraph.
class_name Quarry
extends Boss

const STRIKE := preload("res://scenes/actors/projectiles/bore_strike.gd")
const RUBBLE := preload("res://scenes/actors/projectiles/rubble.gd")
const WATER := preload("res://scenes/level/water_volume.gd")
const DAMAGE_TABLE := preload("res://resources/damage_tables/quarry.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/quarry.tres")

## Boss index 7 (docs/PLAN.md section 4).
const INDEX := 7

## The heaviest body in the roster, and it should be: this is the one that
## digs.
const BODY_NES := Vector2(27.0, 27.0)

# --- Bore -----------------------------------------------------------------------

const BORE_DAMAGE := 4
## Strikes per pattern, and the act frames they open on.
##
## Two, walked apart: the first is aimed where the player was when the tell
## began and the second where they are when it lands, so standing still answers
## the first and running answers the second. Neither answers both, which is what
## makes the pattern a decision rather than a dodge.
const BORE_STRIKES := [0, 30]

# --- Flood ----------------------------------------------------------------------

## How deep the arena floods, in tiles, and for how long.
##
## Deep enough to reach a standing player's head so entering is unmistakable,
## and it lasts most of the pattern -- a flood the player can wait out is a
## flood they never have to re-aim inside.
const FLOOD_DEPTH_TILES := 6.0
const FLOOD_FRAMES := 150

# --- Cave-In --------------------------------------------------------------------

const RUBBLE_BLOCKS := 4
## How high the roof is, in NES px above the floor.
const ROOF_HEIGHT_NES := 150.0
## Act frames the blocks come down on. Spread, so the pattern is a collapse
## rather than a volley.
const RUBBLE_FRAMES := [0, 14, 28, 42]

## Where the last Bore was aimed, for the tests.
var _bore_aim := 0.0


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"quarry_bore"
	display_name = "Quarry"
	contact_damage = 4
	anim_name = &"idle"
	if damage_table == null:
		damage_table = DAMAGE_TABLE
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	super()


func body_size() -> Vector2:
	return BODY_NES * tuning.world_scale


func build_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	# Bore first and most often: it is the pattern that teaches the fight, and
	# the only one whose answer -- look at the floor -- the player has never been
	# asked for.
	out.append(BossPattern.new(&"bore", 30, 64, 40, 1.2)
		.with_anims(&"attack", &"attack", &"idle"))
	out.append(BossPattern.new(&"cavein", 38, 56, 42, 1.0)
		.with_anims(&"jump", &"attack", &"idle"))
	out.append(BossPattern.new(&"flood", 44, 60, 44, 0.8)
		.with_anims(&"walk", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Quarry stands still. Everything it does happens to the room.
	velocity.x = 0.0
	hold_inside_arena()


func tell(pattern: BossPattern, frame: int) -> void:
	velocity.x = 0.0
	if pattern.id == &"bore" and frame == 0:
		_bore_aim = _target_x()


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"bore":
			var index := BORE_STRIKES.find(frame)
			if index >= 0:
				# The first strike is aimed where the player was at the tell;
				# the second at where they are now. Standing still answers one
				# and running answers the other.
				_strike(_bore_aim if index == 0 else _target_x())
		&"cavein":
			if RUBBLE_FRAMES.has(frame):
				_drop_rubble(RUBBLE_FRAMES.find(frame))
		&"flood":
			if frame == 0:
				_flood()


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


# --- Patterns -------------------------------------------------------------------

func _strike(at_x: float) -> void:
	var span := arena_span()
	var strike := STRIKE.new() as BoreStrike
	strike.mark(Vector2(clampf(at_x, span.x, span.y), arena_floor_y()),
		BORE_DAMAGE, tuning)
	_spawn(strike)


## Water over the whole arena floor, for a while.
##
## The whole floor rather than part of it, deliberately: a pool the player can
## stand beside is a pool they never have to re-aim inside, and re-aiming is the
## entire pattern. It is also the only one of Quarry's three that cannot hurt
## anybody, which is what lets it cover everything without being a trap.
func _flood() -> void:
	var span := arena_span()
	var tile := tuning.tile_size()
	var pool := WATER.new() as WaterVolume
	pool.width_tiles = maxf((span.y - span.x) / tile, 1.0)
	pool.depth_tiles = FLOOD_DEPTH_TILES
	# The surface sits above the deck, so the floor of the arena is under water
	# rather than beside it.
	pool.position = Vector2(span.x, arena_floor_y() - FLOOD_DEPTH_TILES * tile)
	_spawn(pool)
	var timer := get_tree().create_timer(float(FLOOD_FRAMES) / 60.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(pool):
			pool.queue_free())


## A block of roof, spaced across the arena rather than aimed.
##
## Not aimed, and this is the one pattern where that is right: the rubble is
## something the player will want to *stand on* afterwards, and debris that
## always landed on the player would always land where they could not use it.
## Spread evenly, the collapse is a hazard on the way down and a staircase after.
func _drop_rubble(index: int) -> void:
	var span := arena_span()
	var t := (float(index) + 0.5) / float(RUBBLE_BLOCKS)
	var block := RUBBLE.new() as Rubble
	block.drop(Vector2(span.x + (span.y - span.x) * t,
		arena_floor_y() - ROOF_HEIGHT_NES * tuning.world_scale),
		arena_floor_y(), tuning)
	_spawn(block)


# --- Helpers --------------------------------------------------------------------

func bore_aim() -> float:
	return _bore_aim


func _target_x() -> float:
	if target == null or not is_instance_valid(target):
		return arena_centre()
	return target.global_position.x


func _spawn(node: Node2D) -> void:
	var level := get_parent()
	if level == null:
		node.free()
		return
	level.add_child(node)
