## One weapon: what it costs, how many it allows on screen, and what it fires.
##
## One resource per weapon in `resources/weapons/`, so adding a weapon is a
## `.tres` and a projectile script rather than a branch in the player.
##
## **This holds a `Script`, not the `PackedScene`** that ARCHITECTURE section 5.6
## sketched. Every projectile in this project is a bare script instantiated with
## `.new()` -- there is no `.tscn` for a buster pellet, because a pellet is one
## Area2D with a rectangle and building that in code is shorter than a scene
## file. A `PackedScene` field would mean authoring eight scenes whose only
## content is a node the script creates anyway.
class_name WeaponData
extends Resource

## Matches the key used in every DamageTable and in WeaponManager's ammo book.
@export var id: StringName = &""
@export var display_name: String = ""

## Instantiated with `.new()` and expected to extend WeaponShot.
@export var projectile_script: Script

## Ammo is a 28-tick bar like health, so one tick is one shot at cost 1.
@export var ammo_max: int = 28
@export var ammo_cost: int = 1

## Live projectiles allowed at once. The buster's 3 is what caps its damage over
## time, since this game has no charge shot to cap instead.
@export var max_on_screen: int = 3
## Frames the player must wait between shots. 0 means the on-screen cap is the
## only limiter, which is how the buster behaves.
@export var fire_cooldown_frames: int = 0

## Damage before the target's DamageTable gets a say. A weakness is a bigger
## number in that table, not a multiplier here (see DamageTable).
@export var damage: int = 1
@export var flags: int = DamageInfo.NONE

## The weapon's own colours: [body, highlight]. The player's hue-rotation shader
## measures its shift from the buster's first entry to this weapon's, so this
## says what colour the weapon *is* and nothing has to also say what colour it
## is relative to (SPRITES.md section 3).
##
## Author it in a `.tres` as `Array[Color]([Color(...), ...])`. A
## `PackedColorArray` there looks right, saves without complaint, and loads as an
## **empty** array -- the shipped weapons all had one, every palette was silently
## empty, and the only symptom was a character who never changed colour.
@export var palette: Array[Color] = []
@export var icon: Texture2D

# --- Charge ---------------------------------------------------------------------
#
# Opt-in per weapon. A weapon that leaves `chargeable` false behaves exactly as
# it did before charging existed, which is why adding this did not touch the
# Tide Crawler or the Arc Lance.
#
# Two stages, like MM4 onward: hold to mid, keep holding to full. Tapping still
# fires a normal shot on the press, so a full charge costs one ordinary shot up
# front and charging is never strictly better than tapping.

@export var chargeable: bool = false
## Frames of holding to reach the first charged stage.
@export var charge_mid_frames: int = 40
## Frames to reach the second. Must exceed `charge_mid_frames`.
@export var charge_full_frames: int = 85

## Instantiated with `.new()` like `projectile_script`, and handed a level of
## 1 (mid) or 2 (full).
@export var charged_projectile_script: Script
@export var charged_mid_damage: int = 2
@export var charged_full_damage: int = 3
@export var charged_ammo_cost: int = 0
@export var charged_max_on_screen: int = 1

## The id a charged shot carries into the damage tables.
##
## **Not the weapon's own id**, and this is the trap: a charged shot tagged
## `buster` looks up `buster` in every boss's table, finds the 1 that tap fire is
## meant to do, and quietly does 1 damage no matter how long you held the button.
## Nothing errors -- the charge just does nothing. Empty means `<id>_charged`.
@export var charged_weapon_id: StringName = &""


## Charge stage for a number of frames held: 0 none, 1 mid, 2 full.
func charge_level_at(frames_held: int) -> int:
	if not chargeable:
		return 0
	if frames_held >= maxi(charge_full_frames, charge_mid_frames + 1):
		return 2
	if frames_held >= charge_mid_frames:
		return 1
	return 0


## How far through the charge, 0..1, for the bar.
func charge_fraction_at(frames_held: int) -> float:
	if not chargeable:
		return 0.0
	var full := float(maxi(charge_full_frames, 1))
	return clampf(float(frames_held) / full, 0.0, 1.0)


func damage_for_level(level: int) -> int:
	return charged_full_damage if level >= 2 else charged_mid_damage


func charged_id() -> StringName:
	if charged_weapon_id != &"":
		return charged_weapon_id
	return StringName("%s_charged" % id)


## Free-form per-weapon numbers, read by that weapon's projectile script.
## Keeps speed/turn-rate/arc constants in the resource with the rest of the
## weapon rather than hard-coded in the script, without giving WeaponData a
## field for every weapon's private business.
@export var tuning: Dictionary = {}


func get_number(key: StringName, fallback: float) -> float:
	return float(tuning.get(key, fallback))
