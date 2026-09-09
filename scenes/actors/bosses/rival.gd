## Ward: the rival, who cannot win and cannot lose.
##
## docs/PLAN.md section 1 asks for "a scripted mid-stage duel with an
## unbeatable, non-lethal rival". Those two words are the whole design and they
## point in opposite directions on purpose:
##
##   * **Unbeatable.** Take him low enough and he stops, salutes and leaves. His
##     health never reaches zero, there is no explosion, and nothing is awarded
##     -- because there is nothing to award. A rival you can kill is a ninth
##     Robot Master with no weapon behind it.
##   * **Non-lethal.** Every hit he lands carries `DamageInfo.NON_LETHAL`, so he
##     can take the player to one point of health and no further. A rival who
##     can end the run turns a set piece into a boss fight with no reward, and
##     the player would learn to fear a scene rather than read it.
##
## What is left, once neither of you can finish it, is a **conversation**. He
## arrives, he shows you what he can do, one of you gets bored first, and he
## goes. That is the only fight in the game with no stake in it, which is
## exactly why it can afford to be the one that says something.
##
## ### He fights the way you do
##
## Ward's three patterns are the player's three verbs: he **shoots**, he
## **jumps**, and he **slides**. No waves, no arcs, no summoned geometry --
## nothing in his kit that the player has not had since M1. It is the cheapest
## possible characterisation and the most legible: the thing that makes him
## unsettling is not a new attack, it is that every attack is one of yours.
##
## He is also the reason `Boss` needed nothing new to express him. He is a
## `Boss` with a shorter fight and a floor under his health.
##
## ### The whistle
##
## MM3's rival announces himself with a two-note whistle before anything is on
## screen, and the pause is the whole trick: the room is empty, the player has
## no idea what is coming, and the game holds. `WHISTLE_FRAMES` is that hold.
##
## **There is no audio in the build yet** -- that is M8 -- so the cue is drawn
## rather than heard, as two notes rising over the empty arena, and `whistled`
## is emitted on the frame it starts so that adding the sound at M8 is one
## `connect` and no change here. A cue that exists only as a `TODO` in a comment
## is a cue that gets forgotten; a cue that exists as a signal with nothing
## listening is a cue that gets connected.
##
## ### TODO(art)
##
## He wears the **player's** sprite frames, tinted. That is greyboxing and it is
## also the correct final answer often enough to be worth saying out loud: a
## rival built from the same parts, in another colour, is the design. If he ever
## gets his own art it should keep the silhouette.
class_name Rival
extends Boss

const ENEMY_SHOT := preload("res://scenes/actors/projectiles/enemy_shot.gd")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/player.tres")

## Not one of the eight, so it records nothing. See `Boss.boss_index`.
const INDEX := -1

const BODY_NES := Vector2(16.0, 24.0)

## The colour that makes him not you.
const TINT := Color(0.86, 0.42, 0.40)

## Frames the arena holds, empty, before he drops in.
##
## 90 -- a second and a half. Long enough that the player stops walking and
## looks at the screen, short enough that it does not read as the game having
## hung. The bar fill is timed off the landing, not off this, so lengthening the
## hold does not shorten the fight.
const WHISTLE_FRAMES := 90

## Health he stops at.
##
## **Comfortably above the biggest single hit in the game**, which matters: the
## withdrawal is triggered from `Health.damaged`, so the check runs on a health
## value that has already been reduced. Ten leaves at least four points under
## any hit the player can land -- a weakness multiplier tops out at 4 -- so he
## can never arrive at zero, which would fire `died` and explode him.
const SURRENDER_HP := 10

## The longest the duel runs if the player never lands a shot.
##
## **A player who hides behind a block still gets to leave.** Without this the
## encounter is a wall for anyone who does not want to fight it, and the one
## fight in the game with no reward is the worst possible place to put a wall.
## 20 seconds is long enough to see all three patterns twice.
const DUEL_FRAMES := 1200

## Frames the withdrawal takes: he rises out of the room the way he came in.
const EXIT_FRAMES := 54
const EXIT_SPEED_PF := 6.0

const SHOT_SPEED_PF := 3.4
const SHOT_DAMAGE := 3
const SHOT_SPACING := 16
const SHOT_COUNT := 3
const MUZZLE_HEIGHT_NES := 15.0

const JUMP_PF := 5.0
const JUMP_RUN_PF := 1.9
const SLIDE_PF := 2.5

## The whistle started. Nothing listens yet; M8's audio will.
signal whistled()
## He has decided the duel is over, and why -- `"beaten"` or `"bored"`.
signal withdrew(reason: StringName)

var _whistle_left := WHISTLE_FRAMES
var _fight_frames := 0
var _leaving := false
var _cue: Node2D = null


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &""
	display_name = "Ward"
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	super()
	if sprite != null:
		sprite.modulate = TINT
	# Everything he touches is non-lethal, contact included. Set on the hitbox
	# rather than remembered at each call site: a flag that has to be added to
	# every attack is a flag that is missing from the one added last.
	if contact != null:
		contact.flags |= DamageInfo.NON_LETHAL
	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)


func body_size() -> Vector2:
	return BODY_NES * tuning.world_scale


## The player's three verbs, in the player's frame counts as nearly as a boss
## pattern can express them.
func build_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	out.append(BossPattern.new(&"shoot", 22, SHOT_SPACING * SHOT_COUNT + 4, 34, 1.4)
		.with_anims(&"idle_shoot", &"attack", &"idle"))
	out.append(BossPattern.new(&"leap", 24, 46, 30, 1.0)
		.with_anims(&"jump", &"jump", &"idle"))
	out.append(BossPattern.new(&"slide", 20, tuning.slide_frames, 32, 1.0)
		.with_anims(&"slide", &"slide", &"idle"))
	return out


# --- The whistle ------------------------------------------------------------------

## The hold before the beam.
##
## `Boss.begin_intro` is what the arena calls, and overriding it here keeps the
## cue with the character who whistles rather than in the arena, which does not
## know that one of its bosses announces himself.
func begin_intro(floor_position: Vector2, p_target: Node2D = null) -> void:
	super(floor_position, p_target)
	# Off screen and out of the way until the notes have finished.
	visible = false
	_whistle_left = WHISTLE_FRAMES
	_show_cue(floor_position)
	whistled.emit()


func is_whistling() -> bool:
	return _whistle_left > 0


func _process_entrance(delta: float) -> void:
	if _whistle_left > 0:
		_whistle_left -= 1
		if _whistle_left > 0:
			return
		visible = true
		if _cue != null:
			_cue.queue_free()
			_cue = null
	super(delta)


func _show_cue(at: Vector2) -> void:
	var level := get_parent()
	if level == null:
		return
	_cue = WhistleCue.new()
	_cue.name = "WhistleCue"
	_cue.position = at - Vector2(0.0, 3.0 * tuning.tile_size())
	_cue.set("total_frames", WHISTLE_FRAMES)
	_cue.set("tile", tuning.tile_size())
	level.add_child(_cue)


# --- The duel --------------------------------------------------------------------

func fight_move(_delta: float) -> void:
	_fight_frames += 1
	if _fight_frames >= DUEL_FRAMES:
		_withdraw(&"bored")
		return
	if current_pattern() == null or current_pattern().id != &"leap":
		if is_on_floor():
			velocity.x = 0.0
	hold_inside_arena()


func tell(_pattern: BossPattern, _frame: int) -> void:
	if is_on_floor():
		velocity.x = 0.0


func act(pattern: BossPattern, frame: int) -> void:
	match pattern.id:
		&"shoot":
			if frame % SHOT_SPACING == 0 and frame / SHOT_SPACING < SHOT_COUNT:
				_fire()
		&"leap":
			if frame == 0:
				velocity = Vector2(
					-float(facing()) * tuning.px_s(JUMP_RUN_PF),
					-tuning.px_s(JUMP_PF))
		&"slide":
			# Toward the player, which is the one of his three verbs that closes
			# distance. A slide away would be a dodge, and he is not dodging --
			# he is showing you the move.
			velocity.x = float(facing()) * tuning.px_s(SLIDE_PF)


func recover(_pattern: BossPattern, _frame: int) -> void:
	if is_on_floor():
		velocity.x = 0.0


func _fire() -> void:
	var shot := ENEMY_SHOT.new() as EnemyShot
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-MUZZLE_HEIGHT_NES * tuning.world_scale)
	shot.launch(at, Vector2(float(facing()), 0.0), SHOT_SPEED_PF, SHOT_DAMAGE, tuning)
	shot.flags |= DamageInfo.NON_LETHAL
	var level := get_parent()
	if level == null:
		shot.free()
		return
	level.add_child(shot)


# --- Leaving ----------------------------------------------------------------------

func _on_damaged(_info: DamageInfo, _taken: int) -> void:
	if health.current <= SURRENDER_HP:
		_withdraw(&"beaten")


## He stops, and goes up.
##
## Routed through `Boss._on_died` rather than around it, because that method is
## where the bookkeeping for "this fight is over" lives -- the dead flag, the
## immunity, the hazard switch, the stopped velocity -- and a second copy of it
## here would be a second copy to forget to update. What changes is only what
## happens *during* the phase, which is `_process_death` below.
func _withdraw(reason: StringName) -> void:
	if _leaving:
		return
	_leaving = true
	_on_died(null)
	withdrew.emit(reason)


func is_leaving() -> bool:
	return _leaving


## The withdrawal, in place of the explosion.
##
## He rises out of the room and the arena's `defeated` handler runs exactly as
## it would for a dead boss -- the walls come down and the player walks on --
## because as far as the arena is concerned the fight being over is the fight
## being over. What it must not be is a death: no bursts, no debris.
func _process_death() -> void:
	global_position.y -= tuning.px_s(EXIT_SPEED_PF) * (1.0 / 60.0)
	if _phase_frames < EXIT_FRAMES:
		return
	phase = Phase.DORMANT
	visible = false
	defeated.emit(self)
	queue_free()


## The two notes, drawn rather than heard until M8 brings audio in.
##
## An inner class so the cue ships with the character who makes it: it has no
## use anywhere else, and a file of its own would be a file to wonder about.
class WhistleCue:
	extends Node2D

	const NOTE := Color(0.96, 0.94, 0.70, 0.9)
	const FADE_FRAMES := 12

	var total_frames := 90
	var tile := 72.0

	var _frames := 0

	func _process(_delta: float) -> void:
		_frames += 1
		queue_redraw()

	func _draw() -> void:
		# Two notes, the second higher and later: a rising two-note call, which
		# is the shape of the cue whether or not anyone can hear it yet.
		_draw_note(0, 0.0, 0.0)
		_draw_note(1, tile * 0.9, -tile * 0.55)

	func _draw_note(index: int, dx: float, dy: float) -> void:
		var start := int(float(total_frames) * (0.15 + 0.3 * float(index)))
		var age := _frames - start
		if age < 0:
			return
		var life := total_frames - start
		var t := clampf(float(age) / float(maxi(life, 1)), 0.0, 1.0)
		var alpha := 1.0 - t * t
		var at := Vector2(dx, dy - tile * 0.7 * t)
		var colour := Color(NOTE, NOTE.a * alpha)
		# A head and a stem: unmistakably a note at any size, and no glyph
		# needed from a font this project does not ship.
		draw_circle(at, tile * 0.16, colour)
		draw_rect(Rect2(at + Vector2(tile * 0.12, -tile * 0.62),
			Vector2(tile * 0.06, tile * 0.62)), colour)
