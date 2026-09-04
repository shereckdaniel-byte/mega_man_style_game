## Tide -- Dawn Boardwalk's Robot Master, and the one that must be beatable with
## nothing but the buster.
##
## That constraint is the whole design. A player who wanders into stage 1 first,
## with no weapons, has to be able to win, so every pattern needs an answer that
## costs no ammo and no item:
##
##   * **Crest** floods the floor. The answer is to jump, and the wave is wide
##     and slow enough to see coming.
##   * **Spout** leaps across the arena. The answer is to move under it -- it
##     always crosses, so standing still is the only losing choice.
##   * **Volley** fires three shots at chest height. The answer is to slide,
##     which is why the gaps between them are wider than a slide is long.
##
## Three patterns with three different answers, so the fight is read rather than
## memorised: ground, air, and torso. The player is never asked for two answers
## at once, which is what would make it unwinnable without a weakness.
class_name Tide
extends Boss

const ENEMY_SHOT := preload("res://scenes/actors/projectiles/enemy_shot.gd")
const CREST_WAVE := preload("res://scenes/actors/projectiles/crest_wave.gd")
## Weakness table. Arc Lance does 4 where the buster does 1 -- the 4x from the
## roster, written as the absolute number the table wants rather than as a
## multiplier (see DamageTable). Tide is deliberately NOT weak to its own
## Tide Crawler: no boss is weak to the weapon it drops.
const DAMAGE_TABLE := preload("res://resources/damage_tables/tide.tres")

## Tide's art.
##
## A boss loads its own, the way it loads its own damage table. Enemies are
## handed theirs by the stage that places them, because one archetype wears a
## different skin per stage -- a boss is one character and there is nothing to
## choose. Leaving it to the caller meant nobody made the call: Tide fought
## through the whole of M5 as an invisible collision box. The fight worked, the
## tests passed, the playthrough won, and the boss was never drawn.
const SPRITE_FRAMES := preload("res://resources/sprite_frames/wave_man.tres")

## Boss index 0: Tide is the first of the eight (docs/PLAN.md section 4).
const INDEX := 0

const BODY_NES := Vector2(20.0, 26.0)

## --- Crest: the floor wave ---
## Its size lives on CrestWave, which owns its own silhouette.
const CREST_SPEED_PF := 2.4
const CREST_DAMAGE := 3
## Height of the wave's centre above the boss's feet, in NES px. Low enough that
## a standing player is hit and a jumping one is not.
const CREST_RIDE_NES := 5.5

## --- Spout: the crossing leap ---
## Launch velocity in NES px/frame.
##
## **Apex goes with the square of this**, which is the trap. 9.5 looks like "a
## bit less than twice the player's 4.94" and is in fact an 11.6-tile jump into
## a room 11 tiles tall: Tide left through the ceiling, kept fighting from
## off-screen, and rained droplets down on a player who could not see or reach
## it. Every test passed -- the fight was mechanically fine and simply not on
## the screen.
##
## 5.3 gives 3.7 tiles against the player's 3.2. Higher than the player, so the
## leap reads as a boss move; well inside the room, so it stays a fight.
## `tests/test_boss.gd` asserts the apex fits.
const SPOUT_JUMP_PF := 5.3
const SPOUT_RUN_PF := 2.2
## Droplets thrown out at the top of the arc.
const SPOUT_DROPS := 3
const SPOUT_DROP_SPEED_PF := 2.8
const SPOUT_DROP_DAMAGE := 2

## --- Volley: the three chest-height shots ---
const VOLLEY_SHOTS := 3
const VOLLEY_SPEED_PF := 3.4
const VOLLEY_DAMAGE := 2
## Frames between shots. Wider than a slide (see PlayerTuning.slide_frames) so
## the answer to the pattern is available rather than frame-perfect.
const VOLLEY_SPACING := 14
## Height of the volley's centre above the boss's feet, in NES px.
##
## Not a free number. The player's standing box is 24 NES tall and the sliding
## one is 14 (PlayerTuning.NES_HITBOX / NES_SLIDE_HITBOX), and the shot is 6
## tall, so its lower edge sits at 18.5 - 3 = 15.5. That clears a slide by 1.5px
## and still catches anyone standing. The first draft put it at 15, whose lower
## edge was *below* the slide box -- the pattern's stated answer did not work,
## and nothing but this arithmetic would have said so.
const VOLLEY_HEIGHT_NES := 18.5

var _spout_direction := -1


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"tide_crawler"
	display_name = "Tide"
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
	# Crest is the most common: it is the pattern that teaches the fight, and it
	# is the safest one to be caught by, so it should be the one seen first.
	out.append(BossPattern.new(&"crest", 30, 12, 44, 1.4)
		.with_anims(&"attack_special", &"attack", &"idle"))
	out.append(BossPattern.new(&"spout", 24, 54, 30, 1.0)
		.with_anims(&"walk", &"jump", &"idle"))
	out.append(BossPattern.new(&"volley", 26, VOLLEY_SPACING * VOLLEY_SHOTS + 4, 34, 1.0)
		.with_anims(&"run", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Tide stands its ground except during Spout's leap, which moves it itself.
	# A boss that also wandered would make the wave's timing unreadable.
	if current_pattern() != null and current_pattern().id == &"spout" \
			and pattern_step() == 1:
		return
	velocity.x = 0.0


func tell(pattern: BossPattern, frame: int) -> void:
	# The tell is where the boss stops and shows what is coming. Nothing is
	# fired here by design -- see BossPattern.
	velocity.x = 0.0
	if pattern.id == &"spout" and frame == 0:
		_spout_direction = -1 if global_position.x > arena_centre() else 1


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"crest":
			if frame == 0:
				_fire_crest()
		&"spout":
			_do_spout(frame)
		&"volley":
			if frame % VOLLEY_SPACING == 0 and frame / VOLLEY_SPACING < VOLLEY_SHOTS:
				_fire_volley_shot()


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


# --- Patterns -------------------------------------------------------------------

## One wide, slow wave along the floor. It does not stop at walls: it is water,
## and a wave that died on the arena's own wall would never reach a player
## standing in the corner -- which is exactly where a cornered player is.
func _fire_crest() -> void:
	var shot := CREST_WAVE.new() as CrestWave
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-CREST_RIDE_NES * tuning.world_scale)
	shot.launch(at, Vector2(float(facing()), 0.0), CREST_SPEED_PF, CREST_DAMAGE, tuning)
	_spawn(shot)


## The crossing leap. One push at the start, then ballistic -- the boss is a
## CharacterBody2D and gravity is already applied by Boss, so steering it in
## mid-air would make the arc unreadable.
func _do_spout(frame: int) -> void:
	if frame == 0:
		velocity = Vector2(
			float(_spout_direction) * tuning.px_s(SPOUT_RUN_PF),
			-tuning.px_s(SPOUT_JUMP_PF))
		return
	# Droplets go out at the apex, which is where the player is committed to
	# whichever side they chose.
	if frame == 18:
		for i in SPOUT_DROPS:
			var spread := (float(i) / float(maxi(SPOUT_DROPS - 1, 1))) * 2.0 - 1.0
			var shot := ENEMY_SHOT.new() as EnemyShot
			shot.launch(global_position - Vector2(0.0, BODY_NES.y * 0.4 * tuning.world_scale),
				Vector2(spread, 0.85).normalized(), SPOUT_DROP_SPEED_PF,
				SPOUT_DROP_DAMAGE, tuning)
			_spawn(shot)
	if is_on_floor() and frame > 4:
		velocity.x = 0.0


func _fire_volley_shot() -> void:
	var shot := ENEMY_SHOT.new() as EnemyShot
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-VOLLEY_HEIGHT_NES * tuning.world_scale)
	shot.launch(at, Vector2(float(facing()), 0.0), VOLLEY_SPEED_PF, VOLLEY_DAMAGE, tuning)
	_spawn(shot)


## Projectiles are parented to the level, not to the boss: they must outlive the
## boss's own death, and they must not travel with it during Spout.
func _spawn(shot: Node2D) -> void:
	var level := get_parent()
	if level == null:
		shot.free()
		return
	level.add_child(shot)
