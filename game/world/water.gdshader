shader_type canvas_item;
// Creek cross-section. Flow runs toward the camera, so surface detail drifts downward.

global uniform vec4 haze_color;
uniform vec4 deep : source_color = vec4(0.16, 0.3, 0.34, 0.85);
uniform vec4 shallow : source_color = vec4(0.36, 0.55, 0.6, 0.55);
uniform float surface_y; // world y of the surface
varying vec2 world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = world.y - surface_y;
	vec4 c = mix(shallow, deep, clamp(d / 110.0, 0.0, 1.0));
	float n = vnoise(vec2(world.x * 0.02, world.y * 0.05 - TIME * 1.5));
	c.rgb += (n - 0.5) * 0.06;
	float line = smoothstep(4.0, 0.0, d) * (0.6 + 0.4 * vnoise(vec2(world.x * 0.05 + TIME, TIME)));
	c.rgb = mix(c.rgb, haze_color.rgb, line * 0.7);
	c.a = max(c.a, line * 0.8);
	COLOR = c;
}
