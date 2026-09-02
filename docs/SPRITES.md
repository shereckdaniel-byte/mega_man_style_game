# Sprite Pipeline — AutoSprite → Godot 4.7

Source of truth for the workflow: AutoSprite's Godot integration guide (AnimatedSprite2D +
SpriteFrames). This document adds the project-specific conventions and replaces the manual
"click frames in the SpriteFrames panel" step with a script, because we regenerate art
often and hand-clicking does not survive that.

---

## 1. Workflow

```
AutoSprite  ──(PNG spritesheet + JSON atlas)──▶  assets/sprites/<kind>/<name>/
                                                        │
                                          tools/autosprite_import.gd (EditorScript)
                                                        ▼
                                    resources/sprite_frames/<name>.tres  (SpriteFrames)
                                                        │
                                                        ▼
                                    AnimatedSprite2D.sprite_frames  in the actor scene
```

1. Generate the character in AutoSprite with the animation set from §4.
2. Export the spritesheet **PNG + JSON atlas** (the JSON carries frame size, columns and
   frame count — we need it; a bare PNG export means falling back to manual grid entry).
3. Drop both files into `assets/sprites/<kind>/<name>/` using the same basename.
4. In the editor, run `tools/autosprite_import.gd` (File ▸ Run, or the Tools menu).
5. Commit the PNG, the JSON, **and** the generated `.tres`.

Actor scenes reference the generated `SpriteFrames` by path, so regenerating art never
requires touching a scene file.

---

## 2. Conventions

| Convention | Value | Why |
| --- | --- | --- |
| Frame cell | 48 × 48 px | Character occupies ~24 px tall inside it; leaves room for muzzle flash, slide dust, and wide poses without changing cell size per animation |
| Anchor | Bottom-centre of the cell aligns to the actor's feet | `AnimatedSprite2D.offset = Vector2(0, -24)` with `centered = true` |
| Palette | 2 primary tones + outline, flat shading, no gradients or AA | Required for the weapon palette-swap shader (§3) |
| Facing | Draw **right-facing only**; mirror with `flip_h` | Halves the frame count |
| Naming | `assets/sprites/player/player.png` + `player.json` | Importer pairs by basename |
| Animation names | `snake_case`, exactly the strings in §4 | The resource lint test asserts these exist |

**Collision never derives from the sprite.** The 48 × 48 cell is art; the hitbox is the
16 × 24 rect from ARCHITECTURE §3. Changing the cell size must not change gameplay.

### Import settings

Nearest-neighbour filtering is set project-wide (ARCHITECTURE §2), and mipmaps are off via
the importer default. If a sprite still looks blurry, check that the node has not
overridden `texture_filter` locally — that is the only remaining place it can go wrong.

---

## 3. Palette swap

The player's colours change with the equipped weapon. Implement as a `ShaderMaterial` on
the `AnimatedSprite2D` that remaps two source colours to the weapon's `palette` array:

```glsl
shader_type canvas_item;
uniform vec4 src_a : source_color;   // the two authored body tones
uniform vec4 src_b : source_color;
uniform vec4 dst_a : source_color;   // weapon palette
uniform vec4 dst_b : source_color;
const float EPS = 0.02;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    if (c.a > 0.5) {
        if (distance(c.rgb, src_a.rgb) < EPS) c.rgb = dst_a.rgb;
        else if (distance(c.rgb, src_b.rgb) < EPS) c.rgb = dst_b.rgb;
    }
    COLOR = c;
}
```

This only works if AutoSprite emits **exactly** those two flat tones on the body. Prompt
for flat NES-style shading, then verify with a colour-count check on the exported PNG
before generating the other seven characters — a gradient here costs a full regeneration.

---

## 4. Animation manifest

### Player (generate first, at M2)

| Animation | Frames | FPS | Loop | Driven by |
| --- | --- | --- | --- | --- |
| `idle` | 1 | — | ✓ | Idle state |
| `idle_blink` | 3 | 8 | ✗ | Idle, every ~4 s |
| `walk` | 3 | 12 | ✓ | Walk state |
| `jump` | 1 | — | ✗ | Jump (rising) |
| `fall` | 1 | — | ✗ | Fall (velocity.y > 0) |
| `land` | 2 | 16 | ✗ | 4-frame cosmetic on floor contact |
| `slide` | 1 | — | ✗ | Slide state |
| `climb` | 2 | 8 | ✓ | Climb, advances only while moving |
| `climb_top` | 1 | — | ✗ | Mounting/dismounting the ladder top |
| `idle_shoot` | 1 | — | ✗ | Idle + `shoot_timer > 0` |
| `walk_shoot` | 3 | 12 | ✓ | Walk + shooting |
| `jump_shoot` | 1 | — | ✗ | Airborne + shooting |
| `climb_shoot` | 1 | — | ✗ | Climb + shooting (one-armed) |
| `hurt` | 2 | 12 | ✓ | Hurt state, plays for `knockback_frames` |
| `teleport_in` | 3 | 12 | ✗ | Stage start beam-down |
| `teleport_out` | 3 | 12 | ✗ | Stage clear |
| `victory` | 2 | 8 | ✗ | Weapon-get screen |

The `_shoot` variants are why the suffix trick in ARCHITECTURE §5.1 matters: 17
animations, not 34, and no extra states.

AutoSprite's stock animation types cover idle / walk / jump / attack / hurt / death
directly. `slide`, `climb`, `teleport_in`, `teleport_out` and the `_shoot` variants are
project-specific — generate those through **Custom Animations** (or Advanced Mode) with
explicit pose descriptions, and generate them in the *same session as the base character*
so the style stays consistent.

### Bosses (M5–M6)

Per boss, minimum set: `idle`, `intro` (teleport-in), `walk` or `hover`, `attack_a`,
`attack_b`, `jump`, `hurt`, `defeat`. Anything beyond that is per-boss and driven by its
pattern state machine.

### Enemies (M4)

Per archetype: `idle`/`move`, `attack` (if it has one), `death` is shared — every enemy
dies into the same 8-particle explosion, so it is one reusable effect scene, not per-enemy
art.

### Shared effects (generate once)

`explosion_small`, `explosion_boss` (larger, longer), `muzzle_flash`, `slide_dust`,
`spawn_beam`, `pickup_sparkle`.

---

## 5. Automated importer

`tools/autosprite_import.gd` — run from the editor. Sketch to implement at M2:

```gdscript
@tool
extends EditorScript

const SRC_ROOT := "res://assets/sprites"
const OUT_ROOT := "res://resources/sprite_frames"

func _run() -> void:
    for json_path in _find_files(SRC_ROOT, "json"):
        var png_path := json_path.get_basename() + ".png"
        if not ResourceLoader.exists(png_path):
            push_warning("No PNG beside %s" % json_path); continue
        var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
        var frames := _build(load(png_path), atlas)
        var out := "%s/%s.tres" % [OUT_ROOT, json_path.get_file().get_basename()]
        ResourceSaver.save(frames, out)
        print("wrote ", out)

func _build(sheet: Texture2D, atlas: Dictionary) -> SpriteFrames:
    # Tolerate naming differences between AutoSprite export versions.
    var cols: int   = _pick(atlas, ["columns", "cols"], 0)
    var count: int  = _pick(atlas, ["frameCount", "frames", "numFrames"], 0)
    var fw: int     = _pick(atlas, ["frameWidth", "width"], 0)
    var fh: int     = _pick(atlas, ["frameHeight", "height"], 0)
    if cols <= 0 and fw > 0: cols = int(sheet.get_width() / fw)
    if fw <= 0 and cols > 0: fw = int(sheet.get_width() / cols)
    assert(cols > 0 and fw > 0 and fh > 0, "atlas missing frame geometry")
    if count <= 0: count = cols * int(sheet.get_height() / fh)

    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    for anim in _animations(atlas, count):
        var name: StringName = anim["name"]
        sf.add_animation(name)
        sf.set_animation_speed(name, anim.get("fps", 12.0))
        sf.set_animation_loop(name, anim.get("loop", true))
        for i in range(anim["from"], anim["to"] + 1):
            var at := AtlasTexture.new()
            at.atlas = sheet
            at.region = Rect2(float((i % cols) * fw), float((i / cols) * fh), float(fw), float(fh))
            at.filter_clip = true
            sf.add_frame(name, at)
    return sf
```

`_animations()` returns the atlas's own animation list when the export includes one
(name + frame range per animation), and otherwise falls back to a sidecar
`<name>.anims.json` we author by hand in the manifest format of §4. Both paths must exist:
AutoSprite exports vary, and the hand-authored sidecar is also how we override FPS and
loop flags without regenerating art.

**Verify the atlas key names against a real export before writing this.** The `_pick`
fallback list above is a guess at the schema; one 30-second look at the first real JSON
replaces the guessing with fact.

### Manual fallback

If the JSON is unavailable, the documented manual route still works: add an
`AnimatedSprite2D`, create a new `SpriteFrames`, use the grid icon (*Add frames from sprite
sheet*), set Horizontal/Vertical to the sheet's columns/rows, select frames in order, and
repeat per animation. Use this only to unblock; get back on the script path before the
frame count multiplies.

---

## 6. State → animation mapping

```gdscript
func _sprite_anim() -> StringName:
    var base: StringName = state_machine.current.anim_name   # each State declares one
    if shoot_timer > 0 and base in SHOOTABLE:                # idle, walk, jump, fall, climb
        return StringName("%s_shoot" % base)
    return base
```

`fall` reuses `jump_shoot` — one airborne firing pose, as in the original. Never gate a
state transition on `animation_finished`; the controller owns timing and the art follows.
The two exceptions, where the animation genuinely owns the duration, are `teleport_in` and
`teleport_out`.

---

## 7. Checklist before generating the other seven bosses

Do all of this on the player and boss #1 first. A style or schema mistake caught here
costs one regeneration; caught later it costs eight.

- [ ] Exported JSON key names confirmed; `autosprite_import.gd` reads a real file.
- [ ] Body uses exactly two flat tones; palette-swap shader verified on three weapons.
- [ ] 48 × 48 cell, feet on the bottom-centre anchor, no vertical drift between animations.
- [ ] Sprites crisp at 1×, 3×, and 6× window scale.
- [ ] Right-facing only; `flip_h` produces no asymmetry artefacts.
- [ ] Resource-lint test passes: every animation name in §4 exists in the generated `.tres`.
