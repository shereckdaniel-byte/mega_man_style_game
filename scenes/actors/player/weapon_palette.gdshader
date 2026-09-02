// Weapon colour for the player sprite: option 2 from SPRITES.md section 3.
//
// The original swapped two indexed palette entries. That needs flat tones, and
// this art has about 230 colours per frame with anti-aliased edges, so an
// exact-match remap has nothing to match. Hue rotation works on any art.
//
// The cost named in that section is real and this shader is written around it:
// a naive rotation drags the dark outline and the white highlights along with
// the body, and the character stops reading as the same character. So the shift
// is weighted by saturation -- greys stay grey, and only the coloured body
// tones move. Luminance is left alone entirely, which keeps the shading and the
// outline exactly where the artist put them.
shader_type canvas_item;

// Hue rotation in turns (0..1), not degrees or radians: hues are authored as
// Color.h, which is already 0..1, so this is the one unit that needs no
// conversion at either end.
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
// How much of the shift the least saturated pixels receive. 0 leaves greys
// untouched, which is what protects the outline.
uniform float grey_floor : hint_range(0.0, 1.0) = 0.0;
// Multiplier on the result's saturation, for a weapon that should read as more
// vivid than the base sprite.
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (abs(hue_shift) < 0.0005) {
		COLOR = src * COLOR;
	} else {
		vec3 hsv = rgb_to_hsv(src.rgb);
		// Saturation decides how much a pixel moves. The outline and the
		// highlights are near-grey and stay put; the body tones carry the
		// weapon's colour.
		float weight = mix(grey_floor, 1.0, hsv.y);
		hsv.x = fract(hsv.x + hue_shift * weight);
		hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
		COLOR = vec4(hsv_to_rgb(hsv), src.a) * COLOR;
	}
}
