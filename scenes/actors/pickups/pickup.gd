## A capsule an enemy left behind: health, weapon energy, a life, or an E-tank.
##
## Until now nothing in the game called `GameState.add_etank()`, so the E-TANK
## row in the pause menu could only ever read x0, and there was no way to recover
## a single hit point inside a stage. That made the game harder than the design
## intends in a way nobody chose -- ARCHITECTURE section 5.3 has specified "small
## health pickup 2, large 10" since M0 and section 5.5 says the respawn rule "is
## what makes farming health drops possible", which is a sentence about a feature
## that did not exist.
##
## ### It falls, and that is the whole reason it is a body
##
## A capsule spawns where the enemy died -- often in the air, because half the
## archetypes fly or hop -- and drops to the floor. A pickup that hung in the air
## where a Gullbot happened to be shot would be unreachable about as often as it
## was convenient. So this is a `CharacterBody2D` that falls, with
## `collision_layer = 0`: it collides *with* the world without anything colliding
## with it, so a capsule can never block a jump or a shot.
##
## The touch is a child `Area2D` on the `pickup` layer (ARCHITECTURE section 4,
## layer 10, reserved for exactly this and unused until now). Separating them is
## not ceremony: the body's shape is what lands on the floor and the area's shape
## is what the player has to reach, and the second wants to be more generous than
## the first.
##
## ### It expires, blinking first
##
## As in the original. Two reasons beyond fidelity: a room that accumulates every
## capsule ever dropped stops reading as a room, and an expiry is what stops
## "farm the same spawn marker" from being strictly better than playing. The
## blink is the fair-warning half -- a capsule that vanished without notice would
## read as a bug, which is the same argument `PhaseBlock` makes about its warn
## frames.
class_name Pickup
extends CharacterBody2D

enum Kind {
	HEALTH_SMALL,
	HEALTH_LARGE,
	AMMO_SMALL,
	AMMO_LARGE,
	ONE_UP,
	ETANK,
}

## What each kind restores. Health numbers are ARCHITECTURE section 5.3's;
## weapon energy mirrors them because a weapon bar is the same 28 ticks.
const SMALL_AMOUNT := 2
const LARGE_AMOUNT := 10

## Body size and the reach of the touch box, in NES px. The touch box is wider
## than the capsule so walking past one collects it, rather than requiring the
## player to stand on it.
const BODY_NES := Vector2(8.0, 8.0)
const TOUCH_NES := Vector2(16.0, 16.0)

## How long a capsule lasts, and how long it blinks before it goes.
const LIFETIME_FRAMES := 480
const BLINK_FRAMES := 120
## Frames per on/off step of the blink. Matches `Boss.HIT_FLASH_PERIOD`'s job:
## fast enough to read as a warning, slow enough to see.
const BLINK_PERIOD := 6

## Upward kick on spawn, in NES px/frame, so a capsule pops out of the enemy
## rather than appearing to be dropped through the floor it was standing on.
const POP_SPEED_PF := 1.6

## The palette, chosen to match the bar each capsule fills rather than to be
## six distinguishable hues. A weapon capsule is the colour of the weapon bar
## (`Hud.WEAPON_FILL`), so "this fills that" is legible without a tutorial.
const HEALTH_COLOUR := Color(0.94, 0.30, 0.32)
const AMMO_COLOUR := Color(1.0, 0.82, 0.36)
const ONE_UP_COLOUR := Color(0.36, 0.62, 0.96)
const ETANK_COLOUR := Color(0.94, 0.30, 0.32)
const SHELL_COLOUR := Color(0.10, 0.12, 0.18)
## The white every capsule carries: the classic items are two-tone, and the
## light half is what makes them read against a dark stage.
const HIGHLIGHT := Color(0.98, 0.98, 1.0)

## Emitted when a player takes it. `kind` rather than the node, because by the
## time a listener runs the node is on its way out.
signal collected(kind: Kind)

@export var kind: Kind = Kind.HEALTH_SMALL

var _tuning: PlayerTuning
var _frames := 0
var _touch: Area2D
var _taken := false
var _spawn_position := Vector2.ZERO


## Spawns one into `parent` at `at`. The convenience `DeathExplosion.burst` has,
## for the same reason: the caller is a dying enemy and should not have to know
## how a capsule is assembled.
##
## **The add is deferred, and the reason is a log rather than a crash.** A
## capsule is dropped from `Enemy._on_died`, which runs inside a `Hitbox` area
## callback -- while the physics server is flushing its queries -- and `_ready`
## builds two collision shapes there. The server refuses to set each new shape's
## `disabled` and `one_way_collision` flags in that window and says so: **nine
## "Can't change this state while flushing queries" errors per capsule.**
##
## Measured rather than assumed, because the obvious conclusion is wrong: those
## flags default to what they were being set to, so the capsule is built
## correctly, falls, lands and is collected either way. Reverting this line and
## re-running the tests passes every one of them. What it costs is a console
## that prints nine errors every time an enemy dies, which is how a real error
## goes unnoticed. `DeathExplosion` is spawned from the same line and never
## tripped it, carrying no collider at all.
##
## Worth recording how it was found. Every test in `tests/test_pickups.gd`
## passed: they drop capsules from test code, which is not inside a physics
## callback. The playthrough bot killed one enemy.
static func drop(parent: Node, at: Vector2, of_kind: Kind) -> Pickup:
	if parent == null:
		return null
	var item := Pickup.new()
	item.kind = _usable_kind(of_kind, parent)
	# Carried rather than assigned, because a node outside the tree has no global
	# position to set. Same shape as `FacetMirror.plant` and `FocusSpot.sweep`.
	item._spawn_position = at
	parent.add_child.call_deferred(item)
	return item


## A weapon capsule dropped before the player owns a weapon, turned into health.
##
## **A capsule nobody can use is not a capsule, it is litter that looks like a
## reward.** Weapon energy is 16% of the drop table and there is nothing at all
## for it to fill until the first boss falls -- so for the whole of a player's
## first stage, one drop in six was a thing that could be walked over and never
## picked up. `_refill` fixes the case where a weapon exists and a different one
## is equipped; this fixes the case where none exists yet.
##
## Health rather than nothing, and the small/large size is kept: the roll said
## "this kill was worth something", and the fix should not quietly make the
## early game stingier than the drop table says it is.
static func _usable_kind(of_kind: Kind, parent: Node) -> Kind:
	if of_kind != Kind.AMMO_SMALL and of_kind != Kind.AMMO_LARGE:
		return of_kind
	var weapons := parent.get_node_or_null(^"/root/WeaponManager")
	if weapons == null:
		return of_kind
	for id: StringName in weapons.unlocked():
		if id != weapons.BUSTER:
			return of_kind
	return Kind.HEALTH_SMALL if of_kind == Kind.AMMO_SMALL else Kind.HEALTH_LARGE


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	# Layer 0: it falls through nothing and nothing falls over it.
	collision_layer = 0
	collision_mask = Layers.mask([Layers.WORLD, Layers.PLATFORM])
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

	var body := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = BODY_NES * _tuning.world_scale
	body.shape = body_rect
	add_child(body)

	_touch = Area2D.new()
	_touch.name = "Touch"
	_touch.collision_layer = Layers.bit(Layers.PICKUP)
	_touch.collision_mask = Layers.bit(Layers.PLAYER_BODY)
	var touch_shape := CollisionShape2D.new()
	var touch_rect := RectangleShape2D.new()
	touch_rect.size = TOUCH_NES * _tuning.world_scale
	touch_shape.shape = touch_rect
	_touch.add_child(touch_shape)
	_touch.body_entered.connect(_on_body_entered)
	add_child(_touch)

	global_position = _spawn_position
	velocity = Vector2(0.0, -_tuning.px_s(POP_SPEED_PF))
	z_index = 20
	queue_redraw()


func frames_left() -> int:
	return maxi(LIFETIME_FRAMES - _frames, 0)


func is_blinking() -> bool:
	return frames_left() <= BLINK_FRAMES


func _physics_process(delta: float) -> void:
	_frames += 1
	if _frames >= LIFETIME_FRAMES:
		queue_free()
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		# The same fall an enemy has, terminal velocity included, so a capsule
		# dropped from the top of a shaft does not outrun the player chasing it.
		velocity.y = minf(
			velocity.y + _tuning.px_s2(_tuning.gravity_pf) * delta,
			_tuning.px_s(_tuning.terminal_velocity_pf))
	move_and_slide()
	if is_blinking():
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	if not _apply(body as Player):
		# Refused rather than wasted. A capsule the player cannot use stays on
		# the floor for when they can -- the same decision `PauseMenu.use_etank`
		# makes about spending an E-tank at full health, and for the same reason:
		# consuming it here is a mistake the game should not let them make.
		return
	_taken = true
	collected.emit(kind)
	Sfx.play(_sound_for(kind))
	queue_free()


## Which chime a kind makes.
##
## Small and large share one: what the player needs to hear is *what* they
## picked up, and they can already see how much. The E-tank and the 1-UP get
## their own because they are the two that change a run rather than a moment.
static func _sound_for(of_kind: Kind) -> StringName:
	match of_kind:
		Kind.ONE_UP:
			return &"pickup_life"
		Kind.ETANK:
			return &"pickup_etank"
		Kind.AMMO_SMALL, Kind.AMMO_LARGE:
			return &"pickup_ammo"
		_:
			return &"pickup_health"


## Applies this capsule's effect. False means it was not used and the capsule
## should stay where it is.
func _apply(player: Player) -> bool:
	match kind:
		Kind.HEALTH_SMALL:
			return player.health.heal(SMALL_AMOUNT) > 0
		Kind.HEALTH_LARGE:
			return player.health.heal(LARGE_AMOUNT) > 0
		Kind.AMMO_SMALL:
			return _refill(SMALL_AMOUNT)
		Kind.AMMO_LARGE:
			return _refill(LARGE_AMOUNT)
		Kind.ONE_UP:
			var state := _game_state()
			if state == null:
				return false
			state.lives += 1
			state.lives_changed.emit(state.lives)
			return true
		Kind.ETANK:
			var tanks := _game_state()
			# An E-tank is banked, not spent, so unlike health it is taken at
			# full health -- it is only refused when the bank is full.
			return tanks != null and tanks.add_etank()
	return false


## Tops up the weapon that needs it most.
##
## **It used to top up only the *equipped* weapon, and that was a bug that made
## a sixth of all drops uncollectable.** The buster has no ammo and never runs
## dry, so a capsule touched while the buster is equipped was refused -- and the
## buster is what the player is holding for most of the game, and all of it
## before the first weapon-get. A player walked over yellow capsules and nothing
## happened, forever, with no way to tell why.
##
## The old behaviour had an argument -- the capsule waits for you to switch to
## the weapon that needs it, so *which* weapon it feeds is a choice you make.
## That is a real choice and it is not worth the cost: the player has to already
## know the rule to see the choice, and if they do not, the game looks broken.
## So the capsule feeds whichever unlocked weapon has the least energy, which is
## what a player switching deliberately would almost always have picked anyway.
##
## Ties go to the earliest in `unlocked()` order, which is boss order, so the
## result is stable rather than dependent on dictionary iteration.
func _refill(amount: int) -> bool:
	var weapons := get_node_or_null(^"/root/WeaponManager")
	if weapons == null:
		return false
	var wanted := _neediest_weapon(weapons)
	if wanted == &"":
		return false
	weapons.refill(wanted, amount)
	return true


## The unlocked weapon furthest from full, or `&""` when every weapon is full
## and there is nothing for a capsule to do.
##
## The buster is skipped because it has no bar to fill. It is in `unlocked()` --
## it is a weapon the player has -- so this is a real exclusion rather than an
## accident of the list.
func _neediest_weapon(weapons: Node) -> StringName:
	var best: StringName = &""
	var lowest := 0
	for id: StringName in weapons.unlocked():
		if id == weapons.BUSTER:
			continue
		var room: int = weapons.max_ammo(id) - weapons.get_ammo(id)
		if room > lowest:
			lowest = room
			best = id
	return best


func _game_state() -> Node:
	return get_node_or_null(^"/root/GameState")


func colour() -> Color:
	match kind:
		Kind.HEALTH_SMALL, Kind.HEALTH_LARGE:
			return HEALTH_COLOUR
		Kind.AMMO_SMALL, Kind.AMMO_LARGE:
			return AMMO_COLOUR
		Kind.ONE_UP:
			return ONE_UP_COLOUR
		Kind.ETANK:
			return ETANK_COLOUR
	return HEALTH_COLOUR


## **The classic four shapes.** Size says small or large and shape says which
## kind, so colour still carries nothing on its own -- the rule `PhaseBlock` set
## for the disappearing blocks, and a down-payment on the colourblind palette
## PLAN.md M8 names.
##
## What changed from the first version is which shapes: it was a square, a bar, a
## disc and a canister, which are distinguishable and mean nothing. These are the
## genre's own vocabulary, and a player who has met them before knows what each
## one does before it lands:
##
##   * **health** -- the two-tone capsule, white over red, lying flat;
##   * **weapon energy** -- the square cell with a bite out of one side;
##   * **1-Up** -- a helmet in silhouette, dome and visor;
##   * **E-tank** -- the can, with a lid band and an E on the front.
##
## All four are drawn rather than textured, so they scale with `world_scale` and
## cost no art. When the real sprites land this function is what they replace.
func _draw() -> void:
	if is_blinking() and (_frames / BLINK_PERIOD) % 2 == 1:
		return
	var scale := _tuning.world_scale
	var unit := BODY_NES.x * scale
	var large := kind in [Kind.HEALTH_LARGE, Kind.AMMO_LARGE, Kind.ONE_UP, Kind.ETANK]
	var body := unit * (1.0 if large else 0.68)
	var tint := colour()
	var edge := maxf(body * 0.14, 1.5)

	match kind:
		Kind.HEALTH_SMALL, Kind.HEALTH_LARGE:
			_health_capsule(body, tint, edge)
		Kind.AMMO_SMALL, Kind.AMMO_LARGE:
			_weapon_cell(body, tint, edge)
		Kind.ONE_UP:
			_helmet(body, tint, edge)
		Kind.ETANK:
			_tank(body, tint, edge)


## The health capsule: a flat two-tone pill, white above and coloured below.
## Wider than it is tall, which is what separates it at a glance from the
## weapon cell's square.
func _health_capsule(body: float, tint: Color, edge: float) -> void:
	var size := Vector2(body * 1.3, body * 0.78)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, SHELL_COLOUR)
	var inner := rect.grow(-edge)
	draw_rect(inner, tint)
	# The light half, on top: the capsule is white over colour, not colour alone.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.46)),
		HIGHLIGHT)


## The weapon cell: a square with a notch cut out of its leading edge. The notch
## is the whole silhouette -- a plain square is a health pickup in bad light.
func _weapon_cell(body: float, tint: Color, edge: float) -> void:
	var half := body * 0.5
	# Shallow. Drafted at 0.34 and the cell read as a "C" rather than a square
	# with a corner taken out of it -- at 8 NES px a deep notch is most of the
	# silhouette, and the shape stopped being square, which is the half of it
	# that separates the cell from the health capsule.
	var bite := body * 0.22
	# Drawn as a polygon so the notch is part of the shape rather than a hole
	# painted over it -- a painted hole shows the stage through it at the wrong
	# moments and reads as a rendering fault.
	var outline := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, -bite * 0.5),
		Vector2(half - bite, 0.0),
		Vector2(half, bite * 0.5),
		Vector2(half, half),
		Vector2(-half, half),
	])
	draw_colored_polygon(outline, SHELL_COLOUR)
	var inner := PackedVector2Array()
	for point in outline:
		inner.append(point * (1.0 - edge / half * 0.5))
	draw_colored_polygon(inner, tint)
	# A bright core bar, so the cell reads as something charged.
	draw_rect(Rect2(Vector2(-half * 0.44, -half * 0.2),
		Vector2(half * 0.88, half * 0.4)), HIGHLIGHT)


## The 1-Up: a helmet. A dome with a flat brow and a visor slot -- the only
## rounded silhouette in the set, which is what makes it findable in a pile.
func _helmet(body: float, tint: Color, edge: float) -> void:
	var half := body * 0.5
	draw_circle(Vector2(0.0, -half * 0.1), half, SHELL_COLOUR)
	draw_circle(Vector2(0.0, -half * 0.1), half - edge, tint)
	# The jaw: a flat base, so it is a helmet rather than a ball.
	draw_rect(Rect2(Vector2(-half, half * 0.2), Vector2(half * 2.0, half * 0.5)),
		SHELL_COLOUR)
	draw_rect(Rect2(Vector2(-half + edge, half * 0.2),
		Vector2(half * 2.0 - edge * 2.0, half * 0.5 - edge)), tint)
	# The visor.
	draw_rect(Rect2(Vector2(-half * 0.62, -half * 0.24),
		Vector2(half * 1.24, half * 0.38)), HIGHLIGHT)


## The E-tank: a can with a lid band and an E on the front. The tallest thing in
## the set, and the only one with a letter on it -- which is fair, because it is
## the only one that is banked rather than spent.
func _tank(body: float, tint: Color, edge: float) -> void:
	var size := Vector2(body * 0.74, body * 1.2)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, SHELL_COLOUR)
	var inner := rect.grow(-edge)
	draw_rect(inner, tint)
	# The lid band across the top.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.2)),
		HIGHLIGHT)

	# The E: three bars and a spine, drawn rather than typed so it scales.
	var stroke := maxf(size.x * 0.13, 1.5)
	var left := -size.x * 0.19
	var right := size.x * 0.2
	var top := -size.y * 0.06
	var bottom := size.y * 0.3
	draw_rect(Rect2(Vector2(left, top), Vector2(stroke, bottom - top)), HIGHLIGHT)
	for y in [top, (top + bottom) * 0.5 - stroke * 0.5, bottom - stroke]:
		draw_rect(Rect2(Vector2(left, y), Vector2(right - left, stroke)), HIGHLIGHT)
