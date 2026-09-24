shader_type canvas_item;
// Low drifting valley fog band. UV.y: 0 top of band, 1 bottom.

global uniform vec4 haze_color;
global uniform float wind;
uniform float density = 0.0;
varying vec2 world;

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

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float n = fbm(world * vec2(0.0011, 0.0035) + vec2(TIME * (0.01 + wind * 0.04), 0.0));
	float band = smoothstep(0.0, 0.5, UV.y) * smoothstep(1.0, 0.8, UV.y);
	COLOR = vec4(haze_color.rgb, density * band * smoothstep(0.25, 0.75, n));
}
