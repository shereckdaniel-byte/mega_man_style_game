## A boss's portrait, cropped to the character rather than to its cell.
##
## **Why this exists.** The art in this project is framed inconsistently inside
## its 256 px cells, and deliberately so — AutoSprite frames every clip
## independently and the importer already normalises the *baseline* for gameplay
## (SPRITES.md §7). What it does not normalise is how much of the cell the
## character fills, because gameplay does not need it to: `Enemy._build_sprite`
## measures each actor's own art height and scales it to that actor's body size,
## so a character drawn small in its cell comes out the right size in the fight.
##
## A portrait has no body size to scale to. Drawing the raw frame puts the whole
## cell on screen, empty margin included, so a character that fills 60% of its
## cell renders 40% smaller than one that fills 95% — for no reason the player
## can see. Measured across the roster:
##
##     Tide (generated 2026-09-02, before the roster)   58-70% of its cell
##     the other seven (generated in one batch)         90-97%
##
## Which is exactly what it looks like on the stage select: Tide noticeably
## smaller than everyone he is standing next to. The art is not wrong — it is
## framed differently, and every other consumer of it already compensates.
##
## So the portrait compensates too, by cropping to the opaque bounds. Nothing is
## regenerated and nothing about the character changes; the empty part of the
## cell simply stops being drawn.
class_name BossPortrait

## Animations to take a portrait from, best first. `idle` is a standing pose in
## every character that has one.
const PREFERRED := ["idle", "idle_right", "walk", "walk_right", "attack"]


## A texture holding just the character, or null when there is no usable art.
static func of(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	var anim := _best_animation(frames)
	if anim.is_empty():
		return null
	var texture := frames.get_frame_texture(anim, 0)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null

	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	# Already tight: hand back the frame rather than copying it.
	if used.position == Vector2i.ZERO and used.size == image.get_size():
		return texture

	var cropped := Image.create(used.size.x, used.size.y, false, image.get_format())
	cropped.blit_rect(image, used, Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)


static func _best_animation(frames: SpriteFrames) -> String:
	for name in PREFERRED:
		if frames.has_animation(name) and frames.get_frame_count(name) > 0:
			return name
	for name in frames.get_animation_names():
		if frames.get_frame_count(name) > 0:
			return name
	return ""
