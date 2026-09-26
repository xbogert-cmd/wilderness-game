shader_type canvas_item;
// Over the world and under the HUD: sunbeams slanting down through the trees
// when the sun is low, and the corners of the view a little darker.

uniform vec2 sun; // the sun, in view pixels
uniform vec2 view = vec2(1920.0, 1080.0);
uniform float rays = 0.0; // 0..1
uniform vec4 ray_col : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float vignette = 0.3;
uniform float cloud_shade = 0.0; // 0..1: shadows of clouds drifting over the land
uniform vec2 scroll; // the camera's world position, so the shadows lie on the land
global uniform float wind;

float hash(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash(i), hash(i + 1.0), f); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * view;
	vec2 d = px - sun;
	float ang = atan(d.x, d.y);
	// broad soft shafts: few, wide, slowly shifting; none right at the sun (no starburst)
	float beams = n1(ang * 9.0 + TIME * 0.04) * 0.65 + n1(ang * 4.0 - TIME * 0.025 + 5.0) * 0.35;
	beams = smoothstep(0.45, 0.85, beams);
	float r = length(d);
	float fall = smoothstep(300.0, 700.0, r) * smoothstep(2400.0, 900.0, r) * smoothstep(0.05, 0.35, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float a = rays * beams * fall * 0.3;
	vec2 c = UV - 0.5;
	float vig = smoothstep(0.45, 0.95, length(c * vec2(1.0, 1.25))) * vignette;
	vec2 w = px + scroll;
	float cl = n2(vec2(w.x * 0.0009 - TIME * (0.01 + wind * 0.03), w.y * 0.0004)) * 0.7 + n2(vec2(w.x * 0.0023 - TIME * 0.02, 3.0)) * 0.3;
	vig += smoothstep(0.5, 0.62, cl) * cloud_shade * 0.2 * smoothstep(0.1, 0.4, UV.y);
	vec3 col = mix(vec3(0.0), ray_col.rgb, a / max(a + vig, 0.0001));
	COLOR = vec4(col, clamp(a + vig, 0.0, 1.0));
}
