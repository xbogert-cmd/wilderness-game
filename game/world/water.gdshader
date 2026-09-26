shader_type canvas_item;
// Creek cross-section. Flow runs toward the camera, so surface detail drifts downward.

global uniform vec4 haze_color;
global uniform float ice; // 0 open .. 1 frozen hard
global uniform float snow;
global uniform float sun_k;
global uniform vec4 sun_col;
global uniform float rain_k; // raining: rings all over the surface
global uniform float fish_rise; // dawn and dusk: fish rising
global uniform float sun_sx; // the sun and moon across the view (0..1), for their paths on the water
global uniform float moon_sx;
global uniform float moon_a;
uniform float fish = 1.0; // this water has fish in it
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
	{ // clear water: deep down you see the creek running on behind (the far reach), not a bowl
		c.a *= 1.0 - 0.75 * smoothstep(20.0, 90.0, d) * (1.0 - mud);
	}
	if (d < 30.0 && ice < 0.55) { // on the surface: rain rings, rising fish, the sun's and moon's path
		float surf = smoothstep(30.0, 0.0, d);
		vec2 rc = vec2(world.x * 0.03, floor(TIME * 1.6));
		float rp = fract(TIME * 1.6);
		float rr = abs(abs(fract(rc.x) - 0.5) * 2.0 - rp) * step(0.5, hash(floor(rc)));
		c.rgb += smoothstep(0.08, 0.0, rr) * smoothstep(8.0, 0.0, d) * rain_k * 0.3 * (1.0 - rp);
		vec2 fc = vec2(world.x * 0.004, floor(TIME / 5.0));
		float fp = fract(TIME / 5.0);
		float fr = abs(abs(fract(fc.x) - 0.5) * 2.0 - fp * 0.8) * step(0.72, hash(floor(fc) + 5.0));
		c.rgb += smoothstep(0.03, 0.0, fr) * smoothstep(10.0, 0.0, d) * fish_rise * fish * 0.35 * (1.0 - fp);
		float wob = vnoise(vec2(world.x * 0.05, d * 0.5 - TIME * 2.0));
		float sp = exp(-abs(SCREEN_UV.x + (wob - 0.5) * 0.02 - sun_sx) * 22.0) * step(0.55, wob);
		float mp = exp(-abs(SCREEN_UV.x + (wob - 0.5) * 0.02 - moon_sx) * 30.0) * step(0.5, wob);
		c.rgb += sun_col.rgb * sp * sun_k * 0.45 * surf + vec3(0.8, 0.85, 0.95) * mp * moon_a * 0.5 * surf;
	}
	{ // the sky in the surface, and the sun glinting off the ripples
		float refl = smoothstep(40.0, 0.0, d) * (1.0 - mud);
		c.rgb = mix(c.rgb, haze_color.rgb * 0.95, refl * 0.45);
		float glint = step(0.9, vnoise(vec2(world.x * 0.09 + TIME * 0.7, d * 0.4 - TIME * 0.3))) * smoothstep(30.0, 2.0, d);
		c.rgb += sun_col.rgb * glint * (0.25 + 0.6 * sun_k) * (1.0 - mud);
	}
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
