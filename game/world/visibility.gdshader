shader_type canvas_item;
// Fog and blizzard over the whole view: clear close around you, thickening with distance, so
// what's ahead comes out of it only as you get near. Drifting wisps; a blizzard's snow streams
// past on the wind.

uniform float fog = 0.0;
uniform float snow = 0.0;
uniform vec2 center; // the player, in view pixels
uniform vec2 view = vec2(1920.0, 1080.0);
uniform vec4 fog_color : source_color = vec4(0.8, 0.82, 0.84, 1.0);
uniform vec4 snow_color : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform float wind_dir = 1.0;
uniform vec2 scroll; // the camera's world position, so the fog stays put as you walk

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 px = UV * view;
	vec2 d = (px - center) * vec2(1.0, 1.5);
	float dist = length(d);
	vec2 w = px + scroll;
	float nf = fbm(w * 0.0022 + vec2(TIME * 0.03, TIME * 0.004));
	float a_fog = fog * smoothstep(170.0, 950.0, dist) * (0.7 + 0.6 * nf);
	a_fog = max(a_fog, fog * 0.18 * nf); // a thin veil even close in
	float ns = fbm(vec2(w.x * 0.003 - TIME * 1.6 * wind_dir, w.y * 0.009 + TIME * 0.2));
	float a_snow = snow * smoothstep(120.0, 720.0, dist) * (0.65 + 0.7 * ns);
	a_snow = max(a_snow, snow * 0.25 * ns);
	float a = clamp(max(a_fog, a_snow), 0.0, 0.96);
	vec3 c = mix(fog_color.rgb, snow_color.rgb, step(a_fog, a_snow));
	COLOR = vec4(c, a);
}
