## Cinder -- Stack's Robot Master, and the sixth of the eight.
##
## The roster's rule: every pattern has an answer that costs no ammo, and **the
## three answers must differ from each other and from every previous boss's.**
## Fifteen are spent by boss six -- Tide's three timings; Arc's movement, timing
## and position; Rust's offence, distance and attrition; Prism's anticipation,
## reading and commitment; Gale's being carried, reading the boss's body and
## leaving the floor. Gale's docstring said plainly that the space of new verbs
## was nearly gone and that its three were old verbs at new prices.
##
## Cinder's three are new verbs, and they are new because they are all about
## **the player acting on the boss's decision rather than on its attack**:
##
##   * **Ashfall** throws a fan of embers that land as burning deck. It aims at
##     wherever the player is standing **when the tell begins**, and the aim is
##     locked there. The answer is **baiting**: stand somewhere you do not need,
##     let it commit, and walk out. Every pattern in the game before this one is
##     answered by reacting to the attack; this one is answered by choosing what
##     the attack will be.
##   * **Flue** opens the stack and drags the player toward it with a **constant**
##     pull while the draught burns at the mouth. The answer is **refusing a
##     constant** -- walking out of a force that never lets up and never varies.
##     Gale's Crosswind is the near miss and it is genuinely different: that is a
##     cycle, so the answer is to wait for the lull. There is no lull here. It is
##     the lesson `ConveyorBelt` spends nineteen rooms teaching, asked once by
##     something that can kill you.
##   * **Backdraft** inhales -- a long, obvious, completely harmless tell during
##     which Cinder cannot move -- and then breathes a wall of flame. The answer
##     is **to attack during the telegraph**. Every other tell in the game is a
##     cue to get out of somewhere. This one is the only window in the fight
##     where the boss is standing still, and a player who spends it retreating
##     has spent the fight's best offer on nothing.
##
## Baiting, refusing, and reading a tell as an opening. None of them is a dodge.
##
## ### Cinder is weak to Frost Lock, which does not exist yet
##
## The position Arc, Rust and Prism were each in until the next stage landed:
## the row is in `resources/damage_tables/cinder.tres` because the table is the
## design, and the fight has to stand up buster-only until stage 7.
## `tools/playthrough.gd` is expected to win it with the buster.
class_name Cinder
extends Boss

const EMBER := preload("res://scenes/actors/projectiles/ash_ember.gd")
const FLAME := preload("res://scenes/actors/projectiles/flame_wall.gd")
const DAMAGE_TABLE := preload("res://resources/damage_tables/cinder.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/cinder.tres")

## Boss index 5 (docs/PLAN.md section 4).
const INDEX := 5

## Wide and low next to Gale's 19x29 mast: a furnace unit should read as
## something with a firebox in it, and the body is what says so before the art.
const BODY_NES := Vector2(25.0, 25.0)

# --- Ashfall --------------------------------------------------------------------

## Embers per fan.
const ASH_EMBERS := 5
## How wide the fan scatters around its aim point, in NES px.
##
## **Wider than the player is (16), so standing still inside it is not an
## answer, and narrower than a jump covers (about 54), so walking out always
## is.** Both halves matter: the first is what makes the pattern a pattern and
## the second is what makes baiting the answer rather than luck.
const ASH_SPREAD_NES := 46.0
## How high the embers are thrown, in NES px/frame up. They have to arc high
## enough to be watched -- the whole pattern is the player following where they
## are going to land.
const ASH_RISE_PF := 4.4
const ASH_DAMAGE := 3

# --- Flue -----------------------------------------------------------------------

## The pull, in NES px/frame, written onto the player every act frame.
##
## **Under `PlayerTuning.walk_speed_pf` and by enough to leave over half the
## walk** -- the rule `ConveyorBelt.speed_pf` and `WindZone.speed_pf` are held
## to, and the one stage 5 learned the expensive way. A drag at or above the walk
## speed is a room the player cannot leave, which is not a pattern, it is a
## trap. `tests/test_cinder.gd` checks it against the tuning.
const FLUE_PULL_PF := 0.6
## How wide the draught burns at the mouth, in NES px.
const FLUE_MOUTH_NES := Vector2(30.0, 22.0)
const FLUE_DAMAGE := 3

# --- Backdraft ------------------------------------------------------------------

## The breath: how far it reaches and how tall it stands, in NES px.
##
## Tall enough that a standing player is caught and **short enough that a jump
## clears it**, which is the one answer the pattern leaves for a player who
## spent the tell attacking and is still in front of it. `tests/test_cinder.gd`
## checks the height against the real jump apex.
const BREATH_NES := Vector2(84.0, 20.0)
const BREATH_FRAMES := 44
const BREATH_DAMAGE := 4

## Where the last Ashfall was aimed. Latched at the tell and not updated after,
## which is the whole of what makes the pattern baitable.
var _ash_aim := 0.0


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"cinder_spray"
	display_name = "Cinder"
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
	# Ashfall first and most often: it is the pattern that teaches the fight and
	# the only one whose answer the player is unlikely to have met before.
	out.append(BossPattern.new(&"ashfall", 36, 18, 46, 1.2)
		.with_anims(&"attack", &"attack", &"idle"))
	out.append(BossPattern.new(&"flue", 40, 74, 38, 1.0)
		.with_anims(&"walk", &"attack", &"idle"))
	# **The longest tell in the fight, and that is the pattern.** It is the
	# player's damage window, and a short one would make Backdraft a thing to
	# run from rather than an offer.
	out.append(BossPattern.new(&"backdraft", 56, 44, 40, 0.9)
		.with_anims(&"idle", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Cinder never chases. It is a furnace: it stands where it is and changes
	# what the floor around it is worth.
	velocity.x = 0.0
	hold_inside_arena()


func tell(pattern: BossPattern, frame: int) -> void:
	velocity.x = 0.0
	if frame != 0:
		return
	if pattern.id == &"ashfall":
		# **Latched here and never updated.** The fan lands where the player was
		# when the tell began, which is what makes standing somewhere you do not
		# need a real move.
		_ash_aim = _target_x()


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"ashfall":
			if frame == 0:
				_throw_fan()
		&"flue":
			_pull()
			if frame == 0:
				_light_mouth()
		&"backdraft":
			if frame == 0:
				_breathe()


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


# --- Patterns -------------------------------------------------------------------

## The fan, thrown at the aim point latched during the tell.
##
## Spread evenly across `ASH_SPREAD_NES` rather than randomly: a scatter the
## player cannot predict is a scatter they cannot bait, and baiting is the
## answer this pattern exists to ask for.
func _throw_fan() -> void:
	var floor_y := arena_floor_y()
	for i in ASH_EMBERS:
		var t := (float(i) + 0.5) / float(ASH_EMBERS) - 0.5
		var land := clampf(_ash_aim + t * ASH_SPREAD_NES * tuning.world_scale,
			arena_span().x, arena_span().y)
		var ember := EMBER.new() as AshEmber
		var from := global_position + Vector2(0.0, -BODY_NES.y * 0.7 * tuning.world_scale)
		# Time of flight from the rise and the fall, so the horizontal speed can
		# be solved rather than guessed -- an ember that overshot its own aim
		# point would make the pattern unbaitable in a way nothing on screen
		# would explain.
		var rise := tuning.px_s(ASH_RISE_PF)
		var flight := 2.0 * rise / tuning.px_s2(AshEmber.FALL_PF)
		var across := (land - from.x) / maxf(flight, 0.001)
		ember.throw(from, Vector2(across, -rise), floor_y, ASH_DAMAGE, tuning)
		_spawn(ember)


## The draught: a constant pull toward the wall Cinder is nearest, written onto
## the player every frame of the act.
##
## It uses `carry_drift_pf` -- the conveyor's channel, not the wind's -- and that
## is the right one on purpose. The conveyor rule is "it takes a player who is
## doing nothing and it never touches a jump", which is exactly what a draught
## along a floor should do, and it means the pull can never shorten a leap.
func _pull() -> void:
	if target == null or not is_instance_valid(target):
		return
	if target is Player:
		(target as Player).carry_drift_pf = float(_mouth_side()) * FLUE_PULL_PF


## Which wall the stack mouth is at: the one Cinder is nearer to, so the player
## is pulled *past* the boss rather than into it. Being dragged into the thing
## with contact damage is a hazard dressed as a mechanic.
func _mouth_side() -> int:
	return -1 if global_position.x < arena_centre() else 1


func _mouth_x() -> float:
	var span := arena_span()
	return span.x if _mouth_side() < 0 else span.y


func _light_mouth() -> void:
	var wall := FLAME.new() as FlameWall
	var pattern := current_pattern()
	var life := pattern.act_frames if pattern != null else 60
	wall.light(Vector2(_mouth_x(), arena_floor_y()), FLUE_MOUTH_NES, life,
		FLUE_DAMAGE, tuning)
	_spawn(wall)


## The breath: a low wall of flame reaching out in front of Cinder.
func _breathe() -> void:
	var reach := BREATH_NES.x * 0.5 * tuning.world_scale
	var at := Vector2(global_position.x + float(facing()) * reach, arena_floor_y())
	var wall := FLAME.new() as FlameWall
	wall.light(at, BREATH_NES, BREATH_FRAMES, BREATH_DAMAGE, tuning)
	_spawn(wall)


# --- Helpers --------------------------------------------------------------------

## Where the last Ashfall was aimed, for the tests and for anything that later
## wants to draw it.
func ash_aim() -> float:
	return _ash_aim


func _target_x() -> float:
	if target == null or not is_instance_valid(target):
		return arena_centre()
	return target.global_position.x


## Projectiles are parented to the level, not to the boss: they must outlive the
## boss's own death, and a burning patch must not travel with it.
func _spawn(node: Node2D) -> void:
	var level := get_parent()
	if level == null:
		node.free()
		return
	level.add_child(node)
