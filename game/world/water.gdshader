shader_type canvas_item;
// Creek cross-section. Flow runs toward the camera, so surface detail drifts downward.

global uniform vec4 haze_color;
global uniform float ice; // 0 open .. 1 frozen hard
global uniform float snow;
uniform vec4 deep : source_color = vec4(0.16, 0.3, 0.34, 0.85);
uniform vec4 shallow : source_color = vec4(0.36, 0.55, 0.6, 0.55);
uniform float surface_y; // world y of the surface (it rises in a flood)
uniform float mud = 0.0; // a flood runs brown
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
	if (d < -1.0) discard; // above the water (the polygon reaches flood height)
	vec4 c = mix(shallow, deep, clamp(d / 110.0, 0.0, 1.0));
	float n = vnoise(vec2(world.x * 0.02, world.y * 0.05 - TIME * 1.5));
	c.rgb = mix(c.rgb, vec3(0.56, 0.46, 0.32) + (n - 0.5) * 0.12, mud * 0.75);
	c.a = mix(c.a, 0.88, mud * 0.6);
	c.rgb += (n - 0.5) * 0.06;
	float line = smoothstep(4.0, 0.0, d) * (0.6 + 0.4 * vnoise(vec2(world.x * 0.05 + TIME, TIME)));
	c.rgb = mix(c.rgb, haze_color.rgb, line * 0.7);
	c.a = max(c.a, line * 0.8);
	// Ice: a pale slab on top that thickens as it freezes, with snow on it once it bears weight.
	float slab = ice * 16.0;
	if (d < slab) {
		float crack = smoothstep(0.93, 0.97, vnoise(vec2(world.x * 0.03, d * 0.2)));
		c = vec4(mix(vec3(0.72, 0.84, 0.9), vec3(0.55, 0.68, 0.76), crack), 0.92);
		if (d < 4.0 * snow * step(0.6, ice)) c = vec4(0.93, 0.95, 0.99, 1.0);
	}
	COLOR = c;
}
