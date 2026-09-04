## Rust -- Breakers' Robot Master, and the third of the eight.
##
## The roster's rule so far: every pattern has an answer that costs no ammo, and
## **the three answers must differ from each other and from the previous
## bosses'.** Tide asked for three timings. Arc asked for movement, timing and
## position. Both of those are dodging, which after two bosses is the whole
## vocabulary the player has been taught, and a third boss made of it would be
## the second boss in a different colour.
##
## So Rust asks for three things that are not dodging:
##
##   * **Scrap** throws a hull plate across the arena. The answer is **offence**
##     -- shoot it down. It is the first attack in the game that can be
##     destroyed, and one buster pellet does it. (Sliding under it also works,
##     which is deliberate: the new idea should have an old answer available
##     while it is being learned.)
##   * **Press** walks Rust at you and slams. The answer is **distance** -- the
##     approach is slower than a walk, so backing off always works. It is the
##     first pattern that is about the gap between the two of you rather than
##     about where a projectile will be.
##   * **Bloom** vents corrosion onto the floor, and the patches stay. The
##     answer is **the floor shrinking** -- a constraint you have to keep
##     accounting for while the next pattern runs, rather than an event you
##     dodge once.
##
## Offence, distance, attrition. And the pattern the player will be given as a
## weapon is the one they had to learn to live with, which is the trade the
## weapon-get is supposed to feel like.
##
## ### Rust is weak to Prism Ray, which does not exist yet
##
## Same position Arc was in until this stage landed: the row is in
## `resources/damage_tables/rust.tres` because the table is the design, and the
## fight has to stand up buster-only until stage 4. `tools/playthrough.gd` is
## expected to win it with the buster.
##
## ### The bound on Bloom
##
## A pattern that takes floor away permanently is a pattern that can make a
## fight unwinnable, so the constraint is structural rather than tuned: the
## arena is divided into `BLOOM_COLUMNS` and patches only ever land in alternate
## ones. Three of the seven columns are clear at all times whatever the pattern
## chooses, and `tests/test_rust.gd` pins that rather than trusting the numbers.
class_name Rust
extends Boss

const SCRAP_PLATE := preload("res://scenes/actors/projectiles/scrap_plate.gd")
const CORROSION := preload("res://scenes/actors/projectiles/corrosion_patch.gd")
const DAMAGE_TABLE := preload("res://resources/damage_tables/rust.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/rust.tres")

## Boss index 2 (docs/PLAN.md section 4).
const INDEX := 2

## Broader than Arc's 20x26. A scrapper that throws hull plates should read as
## the heaviest thing in the room, and the body is what says so before the art
## does.
const BODY_NES := Vector2(26.0, 27.0)

## --- Scrap: the plate you shoot ---
const SCRAP_PLATES := 2
## Frames between the two. Wide enough that the second is a separate decision
## rather than a second layer of the first.
const SCRAP_SPACING := 34
## Travel speed in NES px/frame. Slow: the plate has to be shootable, and a
## player who has never had to shoot a projectile before needs to be given the
## time to work out that they can.
const SCRAP_SPEED_PF := 1.9
const SCRAP_DAMAGE := 4
## Height the plate's *centre* leaves from, above Rust's feet, in NES px.
##
## Chosen from the plate's underside rather than from where it looks right:
## the plate is `ScrapPlate.PLATE_NES.y` tall, so its underside sits at
## `SCRAP_HEIGHT_NES - 9`, and that number has to land between the slide box
## (14 NES px) and the standing box (24). 27 puts it at 18 -- four px of margin
## for a slide, six for a standing player who does not duck.
##
## The first version of this was 20, which put the underside at 11 and made the
## plate unslideable; `tests/test_rust.gd` failed on it. That matters more than a
## near miss usually would, because sliding under is the *old* answer the pattern
## keeps available while its new one is being learned.
const SCRAP_HEIGHT_NES := 27.0

## --- Press: the slam ---
## Approach speed in NES px/frame during the tell. **Below the player's walk of
## 1.375 on purpose** -- that is what makes "back off" an answer that always
## works, rather than one that works when you started far enough away.
const PRESS_STEP_PF := 1.05
## How far in front of Rust the slam reaches, and how tall it is, in NES px.
const PRESS_REACH_NES := 26.0
const PRESS_HEIGHT_NES := 22.0
const PRESS_DAMAGE := 4
## Frames of the act phase the slam is live for. Short: it is a hammer, not a
## wall, and the recovery is where the player is meant to answer.
const PRESS_BITE_FRAMES := 10

## --- Bloom: the corrosion ---
## Columns the arena is divided into for placement. Odd so that alternate
## columns cannot wrap round and meet.
const BLOOM_COLUMNS := 7
const BLOOM_DROPS := 3
const BLOOM_INTERVAL := 16
const BLOOM_DAMAGE := 2

var _bloom_offset := 0


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"rust_bloom"
	display_name = "Rust"
	contact_damage = 4
	anim_name = &"idle"
	if damage_table == null:
		damage_table = DAMAGE_TABLE
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	super()


func body_size() -> Vector2:
	return BODY_NES * tuning.world_scale


## The slam's box, built once and switched on for `PRESS_BITE_FRAMES`.
##
## A child Hitbox rather than a projectile: the slam has no travel and no life
## of its own, and spawning a stationary EnemyShot for it would leave something
## in the level that has to be cleaned up if the fight ends mid-swing.
var _press: Hitbox


func setup() -> void:
	super()
	_press = Hitbox.new()
	_press.name = "Press"
	_press.amount = PRESS_DAMAGE
	_press.weapon_id = &"press"
	_press.one_shot = false
	_press.collision_layer = Layers.bit(Layers.ENEMY_ATTACK)
	_press.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	_press.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PRESS_REACH_NES, PRESS_HEIGHT_NES) * tuning.world_scale
	shape.shape = rect
	_press.add_child(shape)
	add_child(_press)


func press_box() -> Hitbox:
	return _press


func build_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	# Scrap first and most often: it is the pattern that teaches the fight, and
	# the one the player is least likely to already know the answer to.
	out.append(BossPattern.new(&"scrap", 30, SCRAP_SPACING * SCRAP_PLATES + 6, 42, 1.3)
		.with_anims(&"attack", &"attack", &"idle"))
	# The longest tell in the fight, because it is the only pattern whose answer
	# has to be started before it is obvious what is coming.
	out.append(BossPattern.new(&"press", 40, PRESS_BITE_FRAMES + 14, 44, 1.0)
		.with_anims(&"walk", &"attack", &"idle"))
	out.append(BossPattern.new(&"bloom",
			30, BLOOM_INTERVAL * BLOOM_DROPS + 8, 38, 0.85)
		.with_anims(&"jump", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Rust holds its ground except while walking a Press in, which drives its own
	# velocity during the tell.
	var pattern := current_pattern()
	var walking: bool = pattern != null and pattern.id == &"press" and pattern_step() == 0
	if not walking:
		velocity.x = 0.0
	hold_inside_arena()


func tell(pattern: BossPattern, frame: int) -> void:
	# Nothing is fired during a tell, by design -- see BossPattern.
	if pattern.id == &"press":
		_walk_in()
		return
	velocity.x = 0.0
	if frame != 0:
		return
	if pattern.id == &"bloom":
		_bloom_offset = _choose_bloom_offset()


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"scrap":
			if frame % SCRAP_SPACING == 0 and frame / SCRAP_SPACING < SCRAP_PLATES:
				_throw_plate()
		&"press":
			_do_press(frame)
		&"bloom":
			if frame % BLOOM_INTERVAL == 0 and frame / BLOOM_INTERVAL < BLOOM_DROPS:
				_vent(frame / BLOOM_INTERVAL)


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0
	if _press != null:
		_press.monitoring = false


# --- Patterns -------------------------------------------------------------------

## The approach. Slower than a walk, and it stops rather than walking through
## the player: a boss that shoulders you across the room takes the distance
## decision away from you, which is the one thing this pattern is asking for.
func _walk_in() -> void:
	if target == null or not is_instance_valid(target):
		velocity.x = 0.0
		return
	var gap := target.global_position.x - global_position.x
	if absf(gap) <= PRESS_REACH_NES * tuning.world_scale * 0.75:
		velocity.x = 0.0
		return
	velocity.x = signf(gap) * tuning.px_s(PRESS_STEP_PF)


func _do_press(frame: int) -> void:
	velocity.x = 0.0
	if _press == null:
		return
	var live := frame < PRESS_BITE_FRAMES
	_press.monitoring = live
	if not live:
		return
	if frame == 0:
		_press.rearm()
	# In front, at chest height. Re-placed every frame rather than once, because
	# `facing()` is read from the sprite and the sprite may flip mid-swing.
	_press.position = Vector2(
		float(facing()) * (BODY_NES.x * 0.5 + PRESS_REACH_NES * 0.5) * tuning.world_scale,
		-PRESS_HEIGHT_NES * 0.5 * tuning.world_scale)
	_press.tick()


## One hull plate, thrown level at standing height.
##
## Level rather than lobbed: the plate is meant to be shot, and a shot at a
## falling target is a much harder ask than a shot at one holding its line.
func _throw_plate() -> void:
	var plate := SCRAP_PLATE.new() as ScrapPlate
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-SCRAP_HEIGHT_NES * tuning.world_scale)
	plate.launch(at, Vector2(float(facing()), 0.0), SCRAP_SPEED_PF, SCRAP_DAMAGE,
		tuning)
	_spawn(plate)


## Where the patches land.
##
## `_bloom_offset` is 0 or 1, and patches go in every other column from it, so
## the columns they can occupy are either {0,2,4,6} or {1,3,5}. Whichever is
## chosen, the complement is untouched -- which is the bound the docstring
## promises and what `tests/test_rust.gd` checks. `BLOOM_DROPS` is 3, so even
## the four-column offset leaves one of its own alternates clear as well.
func _bloom_column(index: int) -> int:
	return clampi(_bloom_offset + index * 2, 0, BLOOM_COLUMNS - 1)


## Aimed at the player's column, in the sense of choosing the parity that
## includes it. Aiming *at* rather than *away* is the same fairness argument as
## Arc's Curtain: the player is asked to move off a place they can see, not to
## guess where the safe half will be.
func _choose_bloom_offset() -> int:
	if target == null or not is_instance_valid(target):
		return 0
	return _column_at(target.global_position.x) % 2


func _column_at(x: float) -> int:
	var span := arena_span()
	if span.y - span.x < 0.001:
		return BLOOM_COLUMNS / 2
	var t := (x - span.x) / (span.y - span.x)
	return clampi(int(t * float(BLOOM_COLUMNS)), 0, BLOOM_COLUMNS - 1)


func column_centre(column: int) -> float:
	var span := arena_span()
	var width := (span.y - span.x) / float(BLOOM_COLUMNS)
	return span.x + width * (float(column) + 0.5)


func _vent(index: int) -> void:
	var patch := CORROSION.new() as CorrosionPatch
	# On the floor Rust is standing on, not at its own origin height plus a
	# guess: a patch that floated would be a hazard the player walks under.
	patch.land(Vector2(column_centre(_bloom_column(index)), global_position.y),
		BLOOM_DAMAGE, tuning)
	_spawn(patch)


## Projectiles are parented to the level, not to the boss: they must outlive the
## boss's own death, and a patch must not travel with it during a Press.
func _spawn(node: Node2D) -> void:
	var level := get_parent()
	if level == null:
		node.free()
		return
	level.add_child(node)
