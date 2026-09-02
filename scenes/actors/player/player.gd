## The player.
##
## Movement constants come from PlayerTuning and are authored in NES units; this
## script never hard-codes a speed. States live as child nodes under
## StateMachine and own transitions between themselves; the player owns the
## things that are true in every state -- input snapshot, gravity, the sprite,
## the hitbox swap, and the shoot timer.
class_name Player
extends CharacterBody2D

signal state_changed(from: StringName, to: StringName)
## Health reached zero. The Dead state runs the sequence; this is for the HUD,
## the stage and anything else that wants to know.
signal died()
signal respawned()
## Death sequence finished and the last life is gone. The stage decides what a
## game over means; the player only reports it.
signal game_over()
signal shot_fired(shot: WeaponShot)
## The charge crossed into a new stage: 0 released, 1 mid, 2 full.
signal charge_level_changed(level: int)

const FLOOR_NORMAL := Vector2.UP
## Measured from the AutoSprite export's opaque bounding box. The character does
## not fill its 256 px cell -- it is 177 px tall and its feet sit on row 223 --
## so neither the scale nor the ground alignment can be derived from the cell.
## Re-measure if the art is regenerated at a different size; the test
## `test_sprite_feet_sit_on_the_origin` will catch it if these drift.
const SOURCE_ART_HEIGHT := 177.0
const SOURCE_ART_BASELINE := 223.0

## Animations where the character is standing at full height, so all of them
## must be drawn at the same size on screen.
##
## AutoSprite frames every clip independently, so the same character comes back
## drawn at a different scale in each one -- measured head-to-feet, this
## character's upright poses ranged from 149 px (`idle_shoot`) to 197 (`walk`).
## With one scale factor for all of them, that is exactly what you see: the
## character grows 14% when it starts walking and shrinks 13% when it stands
## still and fires. It was noticed by eye before it was measured.
##
## The rest of the clips are left alone deliberately, because they are shorter
## for a *reason* -- `jump` is tucked, `slide` is prone, `death` is collapsing --
## and normalising them to standing height would be the same bug pointed the
## other way. There is no way to tell those two cases apart by measurement, so
## this list is the place the judgement gets written down.
const UPRIGHT_ANIMS: Array[StringName] = [
	&"idle", &"walk", &"idle_shoot", &"walk_shoot", &"hurt", &"climb",
]

## Rendered height an upright pose must hold to, as a fraction of `idle`'s.
## Asserted by tests/test_sprite_frames.gd.
const UPRIGHT_TOLERANCE := 0.03

const BUSTER_SHOT := preload("res://scenes/actors/projectiles/buster_shot.gd")
const WEAPON_PALETTE := preload("res://scenes/actors/player/weapon_palette.gdshader")

## How far the equipped weapon's hue is allowed to drag the sprite, and how much
## of that the near-grey pixels take. The outline and the highlights are what
## keep the character recognisable between weapons, so they take almost none of
## it -- see SPRITES.md section 3, which chose hue rotation over an exact-match
## palette swap because this art has ~230 colours per frame and nothing to match.
const PALETTE_GREY_FLOOR := 0.12
const PALETTE_SATURATION := 1.08

# --- Sword ----------------------------------------------------------------------

## The blade's reach and height in NES px, and how far in front of the player it
## sits. Measured from the feet, like every other actor metric here.
##
## **It starts at the ground, not at the arm.** A slash placed at the arm's
## height would sail over a Dockrat and a Limpet for precisely the reason the
## buster did (Enemy.MIN_HURTBOX_NES) -- and this time with no projectile to
## watch flying past, so it would look like the sword simply did not work.
const MELEE_SIZE_NES := Vector2(20.0, 22.0)
const MELEE_REACH_NES := 16.0
## Damage. Three times a pellet, for standing inside an enemy's reach with no
## way to cancel out of the swing.
const MELEE_DAMAGE := 3
const MELEE_WEAPON_ID := &"sword"

## Where the arm cannon is, per state, in NES pixels from the actor's origin --
## which is at its feet, so y is negative. x is forward, and gets mirrored by
## `facing`. The character is 24 NES px tall and holds the cannon at chest
## height; sliding drops it almost to the floor.
##
## A state with no entry here uses DEFAULT_MUZZLE. Firing a pellet out of the
## character's ankle is the visible symptom of a missing row.
const MUZZLE := {
	&"Idle": Vector2(13.0, -16.0),
	&"Walk": Vector2(13.0, -16.0),
	&"Jump": Vector2(13.0, -18.0),
	&"Fall": Vector2(13.0, -18.0),
	&"Climb": Vector2(10.0, -17.0),
}
const DEFAULT_MUZZLE := Vector2(13.0, -16.0)

@export var tuning: PlayerTuning

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var headroom: RayCast2D = $HeadroomCast
@onready var state_machine: StateMachine = $StateMachine
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox

## +1 right, -1 left. Never 0, so the character keeps facing where it last was.
var facing: int = 1
## Ladders currently overlapping. Climb needs to know one is there.
var ladders: Array[Area2D] = []
## Where this player entered the stage. Used when no checkpoint has been reached
## yet, so a stage that never places one still respawns somewhere sensible.
var entry_position := Vector2.ZERO

var _shoot_frames_left := 0
var _jump_buffer_left := 0
var _coyote_left := 0
var _stand_shape: RectangleShape2D
var _slide_shape: RectangleShape2D
## Live pellets, for the 3-on-screen cap. Freed shots are filtered out on read
## rather than tracked with signals -- queue_free is deferred, so a shot that
## died this frame is still a valid reference until the frame ends.
var _shots: Array[WeaponShot] = []
## Frames left before the selected weapon may fire again. The buster's cooldown
## is 0, so for the buster the on-screen cap is still the only limiter.
var _fire_cooldown := 0
## Frames the fire button has been held. Only counts up for a chargeable weapon.
var _charge_frames := 0
var _charge_level := 0
var melee: Hitbox
## Frozen during a door transition and the teleport-in: physics still runs so
## the player keeps standing on the floor, but input and state changes do not.
var _frozen := false


func _ready() -> void:
	if tuning == null:
		# Autoload when there is one; a fresh default under a bare test tree.
		var autoload := get_node_or_null(^"/root/Tuning")
		tuning = autoload.player if autoload != null else PlayerTuning.new()
	_build_shapes()
	_scale_sprite()
	state_machine.setup(self)
	state_machine.state_changed.connect(
		func(from: StringName, to: StringName) -> void: state_changed.emit(from, to))
	floor_snap_length = tuning.px(2.0)
	entry_position = global_position
	_setup_damage()
	_setup_palette()
	_setup_melee()


func _physics_process(delta: float) -> void:
	if _frozen:
		# Gravity still applies, so a player frozen in mid-air lands rather than
		# hanging there, but nothing else about them moves.
		velocity.x = 0.0
		apply_gravity(delta)
		move_and_slide()
		_update_sprite()
		return
	_tick_timers()
	health.tick()
	if melee != null and melee.monitoring:
		melee.tick()
	state_machine.physics_update(delta)
	move_and_slide()
	_try_switch_weapon()
	_try_shoot()
	_update_sprite()


# --- Shared movement helpers, used by the states ------------------------------

## Applies gravity for one frame and clamps to terminal velocity.
func apply_gravity(delta: float) -> void:
	velocity.y = minf(
		velocity.y + tuning.px_s2(tuning.gravity_pf) * delta,
		tuning.px_s(tuning.terminal_velocity_pf))


## -1, 0 or +1. Uses raw actions rather than get_axis so that holding both
## directions reads as neither, which is what the original did.
func input_direction() -> int:
	var right := 1 if Input.is_action_pressed(&"move_right") else 0
	var left := 1 if Input.is_action_pressed(&"move_left") else 0
	return right - left


## Ground movement is instant-on, instant-off: no acceleration, no friction.
func apply_walk() -> void:
	var direction := input_direction()
	if direction != 0:
		facing = direction
	velocity.x = float(direction) * tuning.px_s(tuning.walk_speed_pf)


func start_jump() -> void:
	velocity.y = -tuning.px_s(tuning.jump_velocity_pf)
	_jump_buffer_left = 0
	_coyote_left = 0


## The hard cut is what gives the original its short hop; do not scale by a
## factor here.
func cut_jump() -> void:
	if velocity.y < 0.0:
		velocity.y = 0.0


## True when jump was pressed this frame or within the buffer window.
func jump_requested() -> bool:
	return _jump_buffer_left > 0


func consume_jump_request() -> void:
	_jump_buffer_left = 0


## Slide is down + jump, as in Mega Man 3 -- not its own action.
func slide_requested() -> bool:
	return jump_requested() and Input.is_action_pressed(&"move_down")


func can_jump_from_ground() -> bool:
	return is_on_floor() or _coyote_left > 0


func on_ladder() -> bool:
	return not ladders.is_empty()


## Whether there is room to stand up out of a slide. Without this check the
## player pops into the ceiling at the end of every tunnel.
func has_headroom() -> bool:
	headroom.force_raycast_update()
	return not headroom.is_colliding()


func use_slide_hitbox(sliding: bool) -> void:
	var shape := _slide_shape if sliding else _stand_shape
	collision.shape = shape
	# Shapes are centred, and the actor's origin is at its feet.
	collision.position.y = -shape.size.y * 0.5


## Freezes input and state. Used by door transitions, which move the player
## themselves for 24 px and must not fight the controller while doing it.
func set_frozen(value: bool) -> void:
	_frozen = value
	if value:
		velocity = Vector2.ZERO
		cancel_charge()


func is_frozen() -> bool:
	return _frozen


func note_shot_fired() -> void:
	_shoot_frames_left = tuning.shoot_pose_frames


# --- Weapons ------------------------------------------------------------------

## Live shots on screen, after dropping any freed since last frame.
func live_shots() -> int:
	# Rebuilt by hand rather than with Array.filter(): filter() returns an
	# untyped Array, which will not assign back into an Array[WeaponShot].
	var alive: Array[WeaponShot] = []
	for shot in _shots:
		if is_instance_valid(shot):
			alive.append(shot)
	_shots = alive
	return _shots.size()


## The WeaponManager, or null when there is not one -- a bare test tree, or a
## `--script` entry point where autoload identifiers do not resolve.
func weapons_autoload() -> Node:
	return get_node_or_null(^"/root/WeaponManager")


## The weapon currently selected, defaulting to the buster.
func current_weapon() -> StringName:
	var weapons := weapons_autoload()
	return weapons.current if weapons != null else &"buster"


func current_weapon_data() -> WeaponData:
	var weapons := weapons_autoload()
	return weapons.data_for(current_weapon()) if weapons != null else null


## Live shots allowed at once for the selected weapon. The buster's comes from
## PlayerTuning, because it is a movement-feel number tuned with the rest of
## them; every other weapon carries its own.
func shot_cap() -> int:
	var data := current_weapon_data()
	return data.max_on_screen if data != null else tuning.max_buster_shots


func can_shoot() -> bool:
	var state := state_machine.current
	if state == null or not state.can_shoot:
		return false
	if health.is_dead():
		return false
	if _fire_cooldown > 0:
		return false
	var weapons := weapons_autoload()
	if weapons != null and not weapons.can_fire(current_weapon()):
		return false
	return live_shots() < shot_cap()


## Arm-cannon position for the current state, in world coordinates.
func muzzle_position() -> Vector2:
	var offset: Vector2 = MUZZLE.get(state_machine.current_name(), DEFAULT_MUZZLE)
	return global_position + Vector2(offset.x * float(facing), offset.y) * tuning.world_scale


## Fires one shot of the selected weapon. Returns it, or null when the shot was
## refused -- by the state, by the on-screen cap, by the cooldown, or by ammo.
##
## The projectile comes from the weapon's resource, so this function has no
## branch per weapon and adding one does not touch the player at all.
func fire() -> WeaponShot:
	if not can_shoot():
		return null
	# Autoloads are reached by path, not by identifier, for the same reason
	# Tuning is above: an autoload name only resolves once the project's
	# autoloads are registered, which is not true for a script run as a
	# `--script` entry point, and not true under a bare test tree either.
	var weapons := weapons_autoload()
	var weapon: StringName = weapons.current if weapons != null else &"buster"
	var data: WeaponData = weapons.data_for(weapon) if weapons != null else null
	if weapons != null and not weapons.consume(weapon):
		return null

	var script: Script = data.projectile_script if data != null else BUSTER_SHOT
	if script == null:
		script = BUSTER_SHOT
	var shot := script.new() as WeaponShot
	if shot == null:
		return null
	shot.launch(muzzle_position(), facing, tuning, data)
	_fire_cooldown = data.fire_cooldown_frames if data != null else 0
	# Parented to the level, not to the player: a pellet does not travel with
	# the shooter, and a shot fired on the frame the player dies must outlive it.
	var level := get_parent()
	if level == null:
		shot.free()
		return null
	level.add_child(shot)
	_shots.append(shot)
	note_shot_fired()
	shot_fired.emit(shot)
	return shot


# --- Sword ----------------------------------------------------------------------

## Builds the blade's hitbox, switched off until a swing turns it on.
##
## It is one Hitbox rather than a node per swing: creating and freeing an Area2D
## inside a 20-frame window means the physics server may not have registered the
## overlap before the window closes, and the swing silently misses.
func _setup_melee() -> void:
	melee = Hitbox.new()
	melee.name = "Melee"
	melee.amount = MELEE_DAMAGE
	melee.weapon_id = MELEE_WEAPON_ID
	# Not one_shot: a swing that catches two enemies in its arc should hit both.
	# Their own i-frames stop it hitting the same one twice.
	melee.one_shot = false
	melee.collision_layer = Layers.bit(Layers.PLAYER_ATTACK)
	melee.collision_mask = Layers.bit(Layers.ENEMY_HURTBOX)
	melee.monitoring = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = MELEE_SIZE_NES * tuning.world_scale
	shape.shape = rect
	melee.add_child(shape)
	add_child(melee)
	_aim_melee()


## Puts the blade in front of the player, standing on the ground line.
func _aim_melee() -> void:
	if melee == null:
		return
	var scale_factor := tuning.world_scale
	melee.position = Vector2(
		float(facing) * MELEE_REACH_NES * scale_factor,
		-MELEE_SIZE_NES.y * 0.5 * scale_factor)


## Called by the Attack state as the swing starts.
func begin_melee() -> void:
	_aim_melee()
	set_melee_active(false)


func end_melee() -> void:
	set_melee_active(false)


func set_melee_active(value: bool) -> void:
	if melee == null:
		return
	if value:
		_aim_melee()
	if melee.monitoring == value:
		return
	melee.monitoring = value
	if value:
		melee.rearm()


func melee_is_active() -> bool:
	return melee != null and melee.monitoring


## Whether a sword swing can start right now.
func melee_requested() -> bool:
	return Input.is_action_just_pressed(&"melee")


func can_melee() -> bool:
	return is_on_floor() and not health.is_dead() and not _frozen


# --- Weapon colour --------------------------------------------------------------

## Puts the hue-rotation shader on the sprite and follows the weapon selection.
##
## The buster is hue shift 0, so the sprite the art was drawn as is the sprite
## the player sees by default and the shader is a no-op on the common path.
func _setup_palette() -> void:
	var material := ShaderMaterial.new()
	material.shader = WEAPON_PALETTE
	material.set_shader_parameter(&"hue_shift", 0.0)
	material.set_shader_parameter(&"grey_floor", PALETTE_GREY_FLOOR)
	material.set_shader_parameter(&"saturation", PALETTE_SATURATION)
	sprite.material = material

	var weapons := weapons_autoload()
	if weapons == null:
		return
	weapons.weapon_changed.connect(apply_weapon_palette)
	apply_weapon_palette(weapons.current)


## Recolours the sprite for a weapon.
##
## The shift is measured from the buster's own palette rather than authored per
## weapon, so the `.tres` files say what colour the weapon *is* and nothing has
## to also say what colour it is relative to. A weapon with no palette entry
## leaves the sprite alone, which is a better failure than a random tint.
func apply_weapon_palette(weapon_id: StringName) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"hue_shift", weapon_hue_shift(weapon_id))


## Hue distance from the buster to this weapon, in turns, wrapped to [-0.5, 0.5]
## so the rotation always takes the short way round the colour wheel.
func weapon_hue_shift(weapon_id: StringName) -> float:
	var weapons := weapons_autoload()
	if weapons == null:
		return 0.0
	var base: WeaponData = weapons.data_for(weapons.BUSTER)
	var data: WeaponData = weapons.data_for(weapon_id)
	if base == null or data == null:
		return 0.0
	if base.palette.is_empty() or data.palette.is_empty():
		return 0.0
	return wrapf(data.palette[0].h - base.palette[0].h, -0.5, 0.5)


# --- Damage -------------------------------------------------------------------

## Health reached zero, however it got there. The Dead state owns the sequence.
func _on_health_died(_info: DamageInfo) -> void:
	cancel_charge()
	died.emit()
	if state_machine.current_name() != &"Dead":
		state_machine.transition_to(&"Dead")


## Applied by the Hurtbox when a hit lands. Knockback is a state, because being
## unable to steer out of it is the whole point -- see states/hurt.gd.
##
## Death is deliberately not handled here: _on_health_died does it, so a kill
## that never went through a hurtbox still stops the player.
func on_damaged(info: DamageInfo, taken: int) -> void:
	if taken <= 0 or health.is_dead():
		return
	# Losing the charge is part of what taking a hit costs. Keeping it would
	# also mean the blast goes off on whatever frame the knockback happens to
	# end, which is not a moment the player chose.
	cancel_charge()
	if info.has_flag(DamageInfo.NO_KNOCKBACK):
		return
	state_machine.transition_to(&"Hurt", {"source_position": info.source_position})


## Called by the Dead state once the burst has played out. Spends a life and
## either returns the player to the checkpoint or reports a game over.
func finish_death() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state == null:
		respawn_at(entry_position)
		return
	if state.consume_life():
		respawn_at(state.respawn_position(entry_position))
	else:
		game_over.emit()


## Full health, back at the checkpoint, with a moment of grace so the thing that
## killed you cannot kill you again on the first frame.
func respawn_at(position: Vector2) -> void:
	global_position = position
	velocity = Vector2.ZERO
	facing = 1
	health.refill()
	health.grant_invulnerability(tuning.iframes)
	use_slide_hitbox(false)
	sprite.visible = true
	state_machine.transition_to(&"Idle")
	respawned.emit()


func is_shooting() -> bool:
	return _shoot_frames_left > 0


func register_ladder(area: Area2D, entered: bool) -> void:
	if entered:
		if not ladders.has(area):
			ladders.append(area)
	else:
		ladders.erase(area)


# --- Internals ----------------------------------------------------------------

func _tick_timers() -> void:
	if _shoot_frames_left > 0:
		_shoot_frames_left -= 1
	if _fire_cooldown > 0:
		_fire_cooldown -= 1
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_left = tuning.jump_buffer_frames
	elif _jump_buffer_left > 0:
		_jump_buffer_left -= 1
	if is_on_floor():
		_coyote_left = tuning.coyote_frames
	elif _coyote_left > 0:
		_coyote_left -= 1


## Wires the damage components. Layers come from Layers rather than literal
## shifts -- see scripts/core/collision_layers.gd for why.
func _setup_damage() -> void:
	health.max_hp = Health.BAR_TICKS
	health.invulnerable_frames = tuning.iframes
	health.current = health.max_hp

	hurtbox.collision_layer = Layers.bit(Layers.PLAYER_HURTBOX)
	# A hurtbox never looks; hitboxes find it. Masking anything here would only
	# cost overlap checks that nothing reads.
	hurtbox.collision_mask = 0
	var box := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tuning.hitbox_size()
	box.shape = rect
	box.position.y = -rect.size.y * 0.5
	hurtbox.add_child(box)

	hurtbox.took_damage.connect(on_damaged)
	# Death is driven by Health, not by the hurtbox. A kill can arrive without
	# any hit at all -- a KillPlane calls Health.kill() directly, bypassing
	# i-frames on purpose -- and routing death through the hurtbox meant those
	# kills set the bar to zero and left the player walking around on it.
	health.died.connect(_on_health_died)


## Fire, and charge.
##
## Pressing fires a normal shot straight away *and* starts the charge, which is
## the MM4-onward behaviour and the reason charging is not simply better than
## tapping: a full charge costs you an ordinary shot up front, and tapping is
## still the higher damage per frame. What the charge buys is one big hit while
## you are busy staying alive, not a faster kill.
func _try_shoot() -> void:
	if Input.is_action_just_pressed(&"shoot"):
		fire()
	_tick_charge()


func _tick_charge() -> void:
	var data := current_weapon_data()
	var chargeable: bool = data != null and data.chargeable

	if not chargeable or not Input.is_action_pressed(&"shoot") or health.is_dead():
		if _charge_frames > 0:
			_release_charge()
		return

	_charge_frames += 1
	var level: int = data.charge_level_at(_charge_frames)
	if level != _charge_level:
		_charge_level = level
		charge_level_changed.emit(level)


## Lets go of the charge, firing the blast if it reached a stage.
func _release_charge() -> void:
	var level := _charge_level
	var data := current_weapon_data()
	_charge_frames = 0
	if _charge_level != 0:
		_charge_level = 0
		charge_level_changed.emit(0)
	if level <= 0 or data == null:
		return
	fire_charged(level, data)


## Drops the charge without firing.
##
## Taking a hit, dying, freezing for a door, or switching weapon all cancel it.
## A charge that survived any of those would go off later at a moment the player
## did not choose -- the worst of which is a blast released by the respawn.
func cancel_charge() -> void:
	_charge_frames = 0
	if _charge_level != 0:
		_charge_level = 0
		charge_level_changed.emit(0)


func charge_frames() -> int:
	return _charge_frames


func charge_level() -> int:
	return _charge_level


## How far through the charge, 0..1, for the bar.
func charge_fraction() -> float:
	var data := current_weapon_data()
	return data.charge_fraction_at(_charge_frames) if data != null else 0.0


## Fires the charged blast. Separate from `fire()` because almost nothing about
## it is shared: a different projectile, a different cap, a different ammo cost
## and -- the part that is easy to get wrong -- a different weapon id, so the
## damage tables can tell it from a tap.
func fire_charged(level: int, data: WeaponData) -> WeaponShot:
	if data.charged_projectile_script == null:
		return null
	var state := state_machine.current
	if state == null or not state.can_shoot or health.is_dead():
		return null
	if _charged_on_screen() >= data.charged_max_on_screen:
		return null

	var weapons := weapons_autoload()
	if weapons != null and data.charged_ammo_cost > 0:
		if not weapons.consume(current_weapon(), data.charged_ammo_cost):
			return null

	var shot := data.charged_projectile_script.new() as WeaponShot
	if shot == null:
		return null
	if shot is ChargedShot:
		(shot as ChargedShot).charge_level = level
	shot.launch(muzzle_position(), facing, tuning, data)

	var level_node := get_parent()
	if level_node == null:
		shot.free()
		return null
	# Damage and the charged weapon id are ChargedShot._configure's job, which
	# runs on entering the tree -- see the note there.
	level_node.add_child(shot)
	_shots.append(shot)
	note_shot_fired()
	shot_fired.emit(shot)
	return shot


## Live charged blasts, which have their own cap so a charge cannot be stacked
## three deep the way pellets can.
func _charged_on_screen() -> int:
	var count := 0
	for shot in _shots:
		if is_instance_valid(shot) and shot is ChargedShot:
			count += 1
	return count


## Cycles weapons without opening the menu.
##
## The pause sub-screen is the original's way and it is still the main one, but
## the input map has carried `weapon_next` and `weapon_prev` since M1 and
## nothing read them -- two actions that a player could rebind and then find did
## nothing. Shoulder-button cycling is also simply better with a gamepad.
##
## Polled here rather than handled in `_unhandled_input` so it obeys the same
## rules as every other input the player takes: nothing happens while frozen,
## and nothing happens while the tree is paused, which is what stops the menu
## and this fighting over the same button.
func _try_switch_weapon() -> void:
	var weapons := weapons_autoload()
	if weapons == null:
		return
	if Input.is_action_just_pressed(&"weapon_next"):
		weapons.cycle(1)
		cancel_charge()
	elif Input.is_action_just_pressed(&"weapon_prev"):
		weapons.cycle(-1)
		cancel_charge()


func _build_shapes() -> void:
	_stand_shape = RectangleShape2D.new()
	_stand_shape.size = tuning.hitbox_size()
	_slide_shape = RectangleShape2D.new()
	_slide_shape.size = tuning.slide_hitbox_size()
	use_slide_hitbox(false)
	# Cast from the top of the slide hitbox up to where the head would be.
	headroom.position = Vector2(0.0, -tuning.slide_hitbox_size().y)
	headroom.target_position = Vector2(
		0.0, -(tuning.hitbox_size().y - tuning.slide_hitbox_size().y))


## The art is ~177 px tall and the character is 108 px in world units, so the
## sprite is minified. That is why the project filters linearly.
##
## `offset` is deliberately not touched when the scale changes. It is in texture
## pixels, inside the space the scale multiplies, so the baseline it points at
## moves with the art and the feet stay on the origin at any factor. Correcting
## it alongside the scale would double the compensation and lift the character
## off the floor.
func _scale_sprite() -> void:
	_apply_art_scale(sprite.animation)
	sprite.centered = true
	# Put the art's baseline -- not the cell's bottom -- on the node origin,
	# which is where the collision box's feet are. Getting this from the cell
	# instead sinks the character into the floor by the cell's bottom padding.
	sprite.offset = Vector2(0.0, -(SOURCE_ART_BASELINE - _cell_size().y * 0.5))


## Scales one animation so an upright pose is always the character's height.
func _apply_art_scale(anim: StringName) -> void:
	var factor := art_scale_for(anim)
	sprite.scale = Vector2(factor, factor)


## The scale factor for an animation.
##
## Upright poses are measured individually and each drawn at exactly the
## character's height. Everything else uses `idle`'s factor -- the same scale a
## standing character is drawn at -- so a tuck or a crouch stays shorter than
## standing by however much the artist drew it shorter.
func art_scale_for(anim: StringName) -> float:
	var reference := _measured_height(&"idle")
	if UPRIGHT_ANIMS.has(anim):
		var own := _measured_height(anim)
		if own > 0.0:
			return tuning.sprite_scale(own)
	if reference > 0.0:
		return tuning.sprite_scale(reference)
	return tuning.sprite_scale(SOURCE_ART_HEIGHT)


## Head-to-feet height of an animation in source pixels, as recorded by the
## importer. 0 when the art predates the measurement or the clip is missing,
## which is what makes SOURCE_ART_HEIGHT still a working fallback.
func _measured_height(anim: StringName) -> float:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_meta(&"body_heights"):
		return 0.0
	var heights: Dictionary = frames.get_meta(&"body_heights")
	return float(heights.get(String(anim), 0))


## Frame size of the current animation, read from the atlas region.
func _cell_size() -> Vector2:
	var frames := sprite.sprite_frames
	if frames == null:
		return Vector2(256.0, 256.0)
	for name in frames.get_animation_names():
		if frames.get_frame_count(name) > 0:
			var tex := frames.get_frame_texture(name, 0)
			if tex != null:
				return tex.get_size()
	return Vector2(256.0, 256.0)


## Checks the sprite offset arithmetic: that the cell padding compensation lines
## SOURCE_ART_BASELINE up with the node origin. Zero means correct.
##
## The sprite is centred, so the cell's centre sits at `offset`; the baseline row
## is `BASELINE - cell_height / 2` below that centre.
##
## This does NOT measure the art. Both terms derive from SOURCE_ART_BASELINE and
## cancel, so it returns zero whatever the pixels look like -- which is why it
## missed the animations whose feet sat up to 15 px off their cell's baseline.
## `tests/test_sprite_frames.gd` reads the actual alpha; the importer normalises
## every animation onto AutoSpriteImporter.BASELINE_ROW so this stays honest.
func sprite_feet_offset() -> float:
	var half_cell := _cell_size().y * 0.5
	var baseline_from_centre := SOURCE_ART_BASELINE - half_cell
	return (sprite.offset.y + baseline_from_centre) * sprite.scale.y


func _update_sprite() -> void:
	sprite.flip_h = facing < 0
	_update_flicker()
	_update_charge_tint()
	var wanted := _sprite_animation()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(wanted):
		if sprite.animation != wanted:
			sprite.play(wanted)
			# The scale belongs to the clip, so it changes with the clip.
			_apply_art_scale(wanted)
	elif sprite.animation != &"idle" and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
		_apply_art_scale(&"idle")


## Pulses the character while the charge is held.
##
## This, not the bar, is the feedback the player actually reads -- their eyes are
## on the character during a fight, and the original conveyed the whole charge
## state this way with no meter at all.
##
## Driven through `modulate` rather than the palette shader's hue, deliberately.
## The hue says which weapon is equipped (SPRITES section 3) and pulsing it would
## make the character read as switching weapons mid-charge. Brightness is a free
## channel. `visible` is left to the i-frame flicker, so the two never fight.
func _update_charge_tint() -> void:
	if _charge_level <= 0:
		if sprite.modulate != Color.WHITE:
			sprite.modulate = Color.WHITE
		return
	# Faster and brighter at full, so the two stages are told apart at a glance.
	var period := 4 if _charge_level >= 2 else 8
	var lift := 0.55 if _charge_level >= 2 else 0.28
	var on := (_charge_frames / period) % 2 == 0
	sprite.modulate = Color(1.0 + lift, 1.0 + lift, 1.0 + lift) if on else Color.WHITE


## Blinks the sprite while invulnerable, two frames on and two frames off. The
## flicker is the only feedback that i-frames are running, so it is deliberately
## coarse enough to see rather than a smooth fade.
##
## Driven off the countdown rather than a separate timer, so it cannot outlive
## the invulnerability and leave the player invisible.
func _update_flicker() -> void:
	var frames_left := health.invulnerable_frames_left()
	if frames_left <= 0:
		sprite.visible = true
		return
	var period := maxi(1, tuning.flicker_period_frames)
	sprite.visible = (frames_left / period) % 2 == 0


## Shooting is not a state -- it is a suffix. That is what keeps 9 states from
## becoming 18. Falls back to the base animation when the `_shoot` variant does
## not exist yet, which is currently true for walk, jump and climb.
func _sprite_animation() -> StringName:
	var base: StringName = state_machine.current.anim_name if state_machine.current != null \
		else &"idle"
	if not is_shooting():
		return base
	var shooting := StringName("%s_shoot" % base)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(shooting):
		return shooting
	return base
