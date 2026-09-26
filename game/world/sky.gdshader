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
uniform float rainbow = 0.0; // after rain, opposite the sun
uniform float towers = 0.0; // thunderheads building on a summer afternoon
uniform float aurora = 0.0; // northern lights, some clear winter nights

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

	{ // on a clear night: a sky full of stars, and the Milky Way across it
		float h2 = hash(floor(p * 520.0) + 17.0);
		col += step(0.9965, h2) * (0.35 + 0.25 * sin(TIME * 2.3 + h2 * 90.0)) * stars * clear;
		vec2 q = vec2(p.x * 0.8 + p.y * 0.55, p.y - p.x * 0.35);
		float band = exp(-pow((q.y - 0.18) * 5.5, 2.0));
		float dust = fbm(q * 6.0) * fbm(q * 13.0 + 4.0);
		col += vec3(0.75, 0.8, 0.95) * band * smoothstep(0.1, 0.5, dust) * 0.22 * stars * clear * (1.0 - UV.y * 0.7);
		col += step(0.9985, hash(floor(p * 900.0) + 3.0)) * band * 0.6 * stars * clear;
	}
	// shooting stars now and then
	float slot = floor(TIME / 9.0);
	float st = fract(TIME / 9.0) * 9.0;
	if (stars > 0.3 && hash(vec2(slot, 1.0)) < 0.6 && st < 0.8) {
		vec2 s0 = vec2(hash(vec2(slot, 2.0)) * aspect * 0.8, hash(vec2(slot, 3.0)) * 0.35);
		vec2 dir = normalize(vec2(0.7, 0.3));
		vec2 head = s0 + dir * st * 0.7;
		vec2 tail = head - dir * 0.12;
		vec2 pa = p - tail; vec2 ba = head - tail;
		float hh = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		float dl = length(pa - ba * hh);
		col += vec3(0.95, 0.97, 1.0) * smoothstep(0.003, 0.0, dl) * hh * (1.0 - st / 0.8) * stars * clear;
	}
	// the northern lights: green curtains, purple along their tops, slowly swaying
	if (aurora > 0.0) {
		float ax = p.x * 3.0 + sin(p.x * 1.3 + TIME * 0.05) * 0.6;
		float curtain = pow(vnoise(vec2(ax * 2.0, TIME * 0.06)), 2.0) * (0.5 + 0.5 * vnoise(vec2(ax * 9.0, TIME * 0.2)));
		float band = smoothstep(0.05, 0.25, UV.y) * smoothstep(0.62, 0.3, UV.y);
		vec3 ac = mix(vec3(0.35, 1.0, 0.55), vec3(0.75, 0.35, 0.9), smoothstep(0.35, 0.1, UV.y));
		col += ac * curtain * band * aurora * 0.55 * clear;
	}
	float ds = distance(p, vec2(sun_uv.x * aspect, sun_uv.y));
	col += sun_color.rgb * (smoothstep(0.034, 0.028, ds) * clear + 0.3 * exp(-ds * 4.0)) * sun_alpha;

	float dm = distance(p, vec2(moon_uv.x * aspect, moon_uv.y));
	col = mix(col, vec3(0.86, 0.88, 0.9), smoothstep(0.02, 0.016, dm) * moon_alpha * clear);

	{
		// low sun: the horizon glows warm on its side, a wide halo round it
		float low = smoothstep(0.35, 0.72, sun_uv.y) * sun_alpha;
		float along = exp(-abs(p.x - sun_uv.x * aspect) * 1.1);
		col += sun_color.rgb * low * along * smoothstep(0.3, 1.0, UV.y) * 0.45 * clear;
		col += sun_color.rgb * 0.18 * exp(-ds * 1.6) * sun_alpha * clear;
		// high thin cloud, even on fair days, catching the colour of a low sun
		float streak = fbm(vec2(p.x * 1.1 + TIME * 0.002, p.y * 11.0 + 3.0)) * fbm(vec2(p.x * 3.0 - 7.0, p.y * 2.0));
		float wisp = smoothstep(0.2, 0.42, streak) * smoothstep(0.75, 0.15, UV.y) * (1.0 - cloud);
		vec3 wisp_col = mix(vec3(1.0), sun_color.rgb * 1.3 + 0.1, low * 0.8) * mix(0.35, 1.0, sun_alpha);
		col = mix(col, wisp_col, wisp * 0.4);
	}
	// thunderheads: towers of cloud far off over the ranges, lit on top, dark underneath
	if (towers > 0.0) {
		float top = 0.55 - fbm(vec2(p.x * 1.2 + 3.0, 0.5)) * 1.2 * towers; // rising well above the ranges
		float edge = top + (fbm(p * 7.0 + vec2(TIME * 0.003, 0.0)) - 0.5) * 0.08;
		float body = smoothstep(edge, edge + 0.05, UV.y) * smoothstep(0.35, 0.7, fbm(vec2(p.x * 2.4, 1.0)));
		vec3 tc = mix(vec3(0.97, 0.95, 0.92), vec3(0.55, 0.58, 0.65), smoothstep(top, 0.95, UV.y));
		tc += sun_color.rgb * 0.25 * exp(-ds * 1.5) * sun_alpha;
		col = mix(col, tc * mix(0.35, 1.0, sun_alpha), body * towers * clear);
	}
	// a rainbow, opposite the sun
	if (rainbow > 0.0) {
		float dr = distance(p, vec2((1.0 - sun_uv.x) * aspect, 1.3));
		float k = (dr - 1.02) / 0.08;
		if (k > 0.0 && k < 1.0) {
			vec3 rb = clamp(abs(fract(vec3(0.0, 0.33, 0.67) + (1.0 - k) * 0.8) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
			col = mix(col, mix(col, rb, 0.6), rainbow * 0.28 * pow(sin(k * PI), 1.5) * smoothstep(0.95, 0.5, UV.y)); // faint and soft-edged
		}
	}
	float n = fbm(vec2(p.x * 2.2 + TIME * (0.004 + wind * 0.012), p.y * 7.0));
	float cov = smoothstep(1.02 - cloud, 1.25 - cloud, n) * smoothstep(0.95, 0.35, UV.y);
	vec3 cc = cloud_color.rgb * (0.85 + 0.25 * n);
	cc += sun_color.rgb * 0.35 * exp(-ds * 2.2) * sun_alpha * smoothstep(0.9, 0.4, cov); // lit edges near the sun
	col = mix(col, cc, clamp(cov + cloud * 0.35, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
