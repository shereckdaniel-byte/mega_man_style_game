## In-game HUD: the player's energy, the selected weapon's ammo, and the boss
## bar during a fight.
##
## A CanvasLayer so it does not scroll with the room, and so a stage only has to
## add it and hand it the player.
##
## Three bars in a row from the left, in the original's order: player, weapon,
## boss. The weapon bar is hidden while the buster is selected, because the
## buster has no ammo and a permanently full bar next to a draining one is
## noise. The boss bar is hidden outside a fight for the same reason.
class_name Hud
extends CanvasLayer

## Inset from the top-left corner, in NES pixels.
const MARGIN_NES := Vector2(12.0, 12.0)
## Gap between bars, in NES pixels.
const BAR_GAP_NES := 10.0

const WEAPON_FILL := Color(1.0, 0.82, 0.36)
const BOSS_FILL := Color(1.0, 0.45, 0.42)

var energy: EnergyBar
var weapon: EnergyBar
var boss: EnergyBar
var charge: ChargeBar

var _scale := 4.5
var _weapons: Node = null
var _boss_health: Health = null
var _player: Player = null


func _ready() -> void:
	layer = 10
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_scale = autoload.player.world_scale

	energy = _add_bar("PlayerEnergy", 0)
	weapon = _add_bar("WeaponAmmo", 1)
	weapon.fill_colour = WEAPON_FILL
	weapon.visible = false
	boss = _add_bar("BossEnergy", 2)
	boss.fill_colour = BOSS_FILL
	boss.visible = false

	# Under the vertical bars rather than beside them: the charge is a thing
	# that happens *while* you are watching the character, so it belongs where a
	# glance already goes, not out at the end of a row.
	charge = ChargeBar.new()
	charge.name = "Charge"
	charge.position = Vector2(MARGIN_NES.x,
		MARGIN_NES.y + EnergyBar.SEGMENT_NES.y * float(Health.BAR_TICKS) * 1.6) * _scale
	add_child(charge)

	_weapons = get_node_or_null(^"/root/WeaponManager")
	if _weapons != null:
		_weapons.weapon_changed.connect(_on_weapon_changed)
		_weapons.ammo_changed.connect(_on_ammo_changed)
		_on_weapon_changed(_weapons.current)


## Points the HUD at a player. Kept separate from _ready so a stage can build
## the HUD before or after the player exists.
func track(player: Player) -> void:
	energy.track(player.health)
	# A respawn refills the bar off-screen; animating it back up would run the
	# refill while the player is already standing there.
	player.respawned.connect(func() -> void: energy.snap_to(player.health.current))
	_player = player
	_refresh_charge_threshold()


## The charge bar is polled rather than driven by a signal.
##
## `charge_level_changed` fires on the two stage boundaries, which is enough to
## flash the character but not enough to *fill* a bar -- the fill moves every
## frame in between. Polling one float off the player is cheaper than a
## per-frame signal and cannot fall out of step with it.
func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or charge == null:
		return
	charge.set_charge(_player.charge_fraction(), _player.charge_level())


## Shows the boss bar and fills it from empty, which is the intro beat.
func show_boss_bar(health: Health) -> void:
	_boss_health = health
	boss.visible = true
	boss.track(health, true)


func hide_boss_bar() -> void:
	if _boss_health != null:
		boss.untrack(_boss_health)
		_boss_health = null
	boss.visible = false


func _add_bar(bar_name: String, column: int) -> EnergyBar:
	var bar := EnergyBar.new()
	bar.name = bar_name
	var step := EnergyBar.SEGMENT_NES.x + EnergyBar.BORDER_NES * 2.0 + BAR_GAP_NES
	bar.position = (MARGIN_NES + Vector2(float(column) * step, 0.0)) * _scale
	add_child(bar)
	return bar


## Where the threshold mark sits depends on the equipped weapon's own timings,
## so it moves when the weapon does.
func _refresh_charge_threshold() -> void:
	if charge == null or _weapons == null:
		return
	var data: WeaponData = _weapons.current_data()
	if data == null or not data.chargeable or data.charge_full_frames <= 0:
		charge.set_threshold(1.0)
		return
	charge.set_threshold(float(data.charge_mid_frames) / float(data.charge_full_frames))


func _on_weapon_changed(weapon_id: StringName) -> void:
	_refresh_charge_threshold()
	if _weapons == null:
		return
	# The buster has no ammo, so it gets no bar. Everything else does.
	if weapon_id == _weapons.BUSTER:
		weapon.visible = false
		return
	weapon.visible = true
	weapon.ticks = _weapons.max_ammo(weapon_id)
	weapon.snap_to(_weapons.get_ammo(weapon_id))


func _on_ammo_changed(weapon_id: StringName, amount: int) -> void:
	if _weapons == null or weapon_id != _weapons.current:
		return
	weapon.set_value(amount)
