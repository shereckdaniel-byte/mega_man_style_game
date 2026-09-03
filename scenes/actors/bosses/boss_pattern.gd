## One attack a boss can choose, as three counted phases.
##
## **Tell, act, recover** -- in that order, always. A boss that can attack
## without a tell is a boss the player can only survive by memorising, and the
## point of this class is that there is nowhere to put an attack that skips it:
## the frame counts are the constructor, and `Boss` runs them in order. Making
## the telegraph part of the *shape* of a pattern is the difference between a
## rule the design doc states and a rule the code keeps.
##
## Frames rather than seconds, because everything else in this project counts
## physics frames and a headless test can step them by hand.
class_name BossPattern
extends RefCounted

## Windup. The boss is committed and visibly about to do something; the player
## reads this and moves. No damage comes out during a tell.
var tell_frames: int
## The attack itself. `Boss.act()` is called once per frame with the frame index.
var act_frames: int
## Cooldown. The boss is open here -- this is when the player gets to shoot back,
## so a pattern with no recovery is a pattern with no counterplay.
var recover_frames: int

## Identifies the pattern to the boss's `act()` and `tell()`.
var id: StringName
## Relative likelihood when the boss picks its next pattern. Weights rather than
## a fixed cycle so the fight does not become a memorised loop.
var weight: float

## Animations for each phase. Empty means "leave whatever is playing alone".
var tell_anim: StringName
var act_anim: StringName
var recover_anim: StringName


func _init(p_id: StringName, p_tell: int, p_act: int, p_recover: int,
		p_weight: float = 1.0) -> void:
	id = p_id
	tell_frames = maxi(p_tell, 1)
	act_frames = maxi(p_act, 1)
	recover_frames = maxi(p_recover, 0)
	weight = maxf(p_weight, 0.0)
	tell_anim = &""
	act_anim = &""
	recover_anim = &""


## Fluent setter for the three animations, so a boss can declare a pattern in
## one statement instead of five.
func with_anims(p_tell: StringName, p_act: StringName,
		p_recover: StringName = &"") -> BossPattern:
	tell_anim = p_tell
	act_anim = p_act
	recover_anim = p_recover
	return self


func total_frames() -> int:
	return tell_frames + act_frames + recover_frames
