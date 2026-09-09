## A fortress stage: the four that come after the eight.
##
## **Almost nothing.** That is the point of the file and the reason it is worth
## reading: a fortress stage is an `AuthoredStage` with three differences, and
## everything else -- the room table, the deck, the doors, the checkpoints, the
## enemies, the boss arena, the ledger, the save -- is the machinery eight
## stages already share. If the fortress had needed a second base class the
## first one would have been wrong.
##
## The three differences:
##
##   1. **It is walked, not chosen.** `GameState.fortress_stage()` says which
##      one the player is up to, and clearing one leads directly into the next
##      instead of back to the grid. Four stages that each returned to the stage
##      select would be four stages the player re-enters through a menu, which
##      is the shape of the first half of the game and the opposite of what the
##      last quarter of it should feel like.
##   2. **Its bosses drop nothing.** There is no ninth weapon and no ninth cell
##      on the grid, so the boss carries `boss_index = -1` and an empty
##      `weapon_id`, and `AuthoredStage` skips the award screen for it.
##   3. **Clearing it writes a fortress bit, not a boss bit**, which is what the
##      password's four new cells carry.
##
## ### Why the chain runs through `GameState` rather than a `next_scene` field
##
## Because the player can die, quit, and come back. A field would say what
## follows this stage; `fortress_stage()` says where the player *is*, which is
## the question that has to be answered on a cold boot from a save or a password
## as well as on the frame after a boss dies. One rule, one answer, and the
## stage after this one is simply the one the rule names next.
class_name FortressStage
extends AuthoredStage


## One theme for all four.
##
## They are one place with one backdrop, and four themes for it would be four
## answers to a question that has one -- the same argument the shared backdrop
## makes (`scenes/stages/fortress/parallax_background.gd`).
func music_track() -> StringName:
	return &"fortress"


## Which of the four this is, 0-3. Subclasses must say.
func fortress_index() -> int:
	return -1


## Turns a Robot Master's script into the fortress's version of it.
##
## **The fight is the same fight.** Same patterns, same tells, same acts, same
## art -- what changes is that the openings are shorter, there is no weapon at
## the end of it, and beating it does not claim a master the player already
## beat. That is M7's first bullet ("mini-bosses reusing earlier boss AI at
## higher aggression") in four lines, and it is four lines because `aggression`
## was built to only ever shorten recovery: see `Boss.aggression` for why
## touching the tell instead would have made this a different fight in the same
## sprite.
##
## Subclasses call it from `configure_boss`.
func as_reprise(boss: Boss, at_aggression: float, called: String) -> void:
	boss.boss_index = -1
	boss.weapon_id = &""
	boss.display_name = called
	boss.aggression = at_aggression


## Clearing a fortress stage leads into the next one, or out of the game.
##
## **The bit is set before `stage_cleared` is emitted**, deliberately, because
## `AuthoredStage` saves on that signal: a save written first would record a
## fortress stage the player has already finished as still ahead of them, and
## the one moment that matters most for the save to be right is the moment the
## run advances.
func _on_stage_exited() -> void:
	var state := get_node_or_null(^"/root/GameState")
	if state != null:
		state.mark_fortress_cleared(fortress_index())
	stage_cleared.emit()
	_go_to_next()


## Into the next fortress stage, or -- once there is no next one -- out.
##
## The fortress lands one stage at a time, so "the next one is not on disk yet"
## is a state this has to survive for as long as M7 is being built. It returns
## to the stage select, which is honest: the grid will show the fortress cell
## sitting on a stage that says NOT BUILT, and that is exactly what is true.
func _go_to_next() -> void:
	var router := get_node_or_null(^"/root/SceneRouter")
	if router == null:
		return
	var state := get_node_or_null(^"/root/GameState")
	var next: int = int(state.fortress_stage()) if state != null else -1
	if next >= 0 and StageRoster.fortress_is_built(next):
		router.goto(String(StageRoster.fortress_entry(next)["scene"]))
		return
	router.goto_stage_select()
