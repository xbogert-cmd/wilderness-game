shader_type canvas_item;
// Screen-space sky: gradient, sun, moon, stars, and weather-driven cloud cover.

global uniform float wind;
uniform vec4 top_color : source_color;
uniform vec4 horizon_color : source_color;
uniform vec4 sun_color : source_color;
uniform vec4 cloud_color : source_color;
uniform vec2 sun_uv = vec2(0.5, 0.3);
uniform vec2 moon_uv = vec2(0.5, 0.3);
uniform float sun_alpha = 1.0;
uniform float moon_alpha = 0.0;
uniform float stars = 0.0;
uniform float cloud = 0.1;
uniform float aspect = 1.7778;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec3 col = mix(top_color.rgb, horizon_color.rgb, smoothstep(0.0, 0.75, UV.y));
	float clear = 1.0 - clamp(cloud * 1.1, 0.0, 1.0);

	float h = hash(floor(p * 220.0));
	col += step(0.9972, h) * (0.55 + 0.45 * sin(TIME * 1.5 + h * 60.0)) * stars * clear * (1.0 - UV.y);

	float ds = distance(p, vec2(sun_uv.x * aspect, sun_uv.y));
	col += sun_color.rgb * (smoothstep(0.034, 0.028, ds) * clear + 0.3 * exp(-ds * 4.0)) * sun_alpha;

	float dm = distance(p, vec2(moon_uv.x * aspect, moon_uv.y));
	col = mix(col, vec3(0.86, 0.88, 0.9), smoothstep(0.02, 0.016, dm) * moon_alpha * clear);

	float n = fbm(vec2(p.x * 2.2 + TIME * (0.004 + wind * 0.012), p.y * 7.0));
	float cov = smoothstep(1.02 - cloud, 1.25 - cloud, n) * smoothstep(0.95, 0.35, UV.y);
	col = mix(col, cloud_color.rgb * (0.85 + 0.25 * n), clamp(cov + cloud * 0.35, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
