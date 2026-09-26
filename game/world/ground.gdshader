shader_type canvas_item;
// Below the line you walk on is the top of the ground, seen from a little above
// and running toward you (UV.y = px below the line): grass and bare earth in patches, stones,
// the creeks flowing out toward you, snow in winter. Nearer is bigger and darker. Underground
// it goes back to the cut earth, since you're in it.

global uniform float snow;
global uniform float ice;
global uniform float autumn;
global uniform float under;
global uniform float sun_k;
global uniform vec4 sun_col;
global uniform vec4 haze_color;
global uniform float cam_x;
global uniform float frost; // 0..1 white frost on a cold clear morning
global uniform float wet; // 0..1 rained on: darker ground, puddles in the hollows
global uniform float rain_k; // raining now: rings on the puddles
global uniform float bloom; // spring into early summer: wildflowers (UV.x: how thick they come here)
global uniform float wind;
global uniform float wind_dir; // the view's centre: nearer ground slides past faster (parallax)
uniform vec4 creeks = vec4(0.0, -1.0, 0.0, -1.0); // x and half-width of up to two creeks here
uniform vec4 soil_top : source_color = vec4(0.36, 0.27, 0.19, 1.0);
uniform vec4 soil_deep : source_color = vec4(0.2, 0.15, 0.11, 1.0);
uniform vec4 water_col : source_color = vec4(0.3, 0.46, 0.5, 1.0); // the same as the far reaches of the creek
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

vec3 creek_out(float cx, float half_w, float d, vec2 w, vec3 col, float persp, float v) {
	if (half_w <= 0.0) return col;
	float grow = 1.0 + d / 380.0;
	float c = cam_x + (cx - cam_x) * grow; // it runs out toward you: nearer, it's wider and slides past faster
	float spread = half_w * grow;
	float k = smoothstep(spread, spread - 14.0, abs(w.x - c));
	float bank = smoothstep(spread + 26.0 * persp, spread, abs(w.x - c)) - k;
	col = mix(col, col * 0.6, clamp(bank, 0.0, 1.0) * 0.8); // wet stones and mud along the banks
	if (k <= 0.0) return col;
	float flow = vnoise(vec2((w.x - c) * 0.03 / persp, v * 0.09 - TIME * 1.4));
	vec3 water = mix(water_col.rgb, water_col.rgb * 0.62, smoothstep(140.0, 520.0, d)); // darker only right up close
	water += (flow - 0.5) * 0.08 + step(0.86, flow) * 0.12;
	vec3 frozen = mix(vec3(0.72, 0.82, 0.88), vec3(0.92, 0.95, 0.99), snow);
	water = mix(water, frozen, smoothstep(0.55, 0.7, ice));
	return mix(col, water, k);
}

void fragment() {
	float d = max(UV.y, 0.0);
	float persp = 1.0 + d / 90.0;
	float u = (world.x - cam_x) / persp + cam_x; // the same ground, bigger the nearer it is
	float v = 60.0 * log(1.0 + d / 30.0);
	vec3 top = COLOR.rgb;
	float trail = clamp((1.0 - COLOR.a) * 2.0, 0.0, 1.0);
	vec3 earth = mix(top, soil_top.rgb, 0.75) * 0.9;
	vec3 straw = vec3(0.62, 0.55, 0.36) * (0.8 + 0.4 * top.g);
	vec3 grass = mix(top, straw, autumn * 0.6);
	grass *= 0.9 + 0.22 * fbm(vec2(u * 0.0025, v * 0.02)); // lusher and thinner stretches
	float patches = fbm(vec2(u * 0.006, v * 0.018) + 7.0);
	vec3 col = mix(grass, earth, smoothstep(0.6, 0.72, patches));
	// grass: short upright strokes, lit tips and dark roots, bigger nearer
	vec2 gc = vec2(u * 0.09, v * 0.16);
	float grain = vnoise(gc) * 0.6 + vnoise(gc * 2.3 + 11.0) * 0.4;
	col *= 0.84 + 0.3 * grain;
	col = mix(col, grass * 1.22, smoothstep(0.62, 0.8, vnoise(vec2(u * 0.05, v * 0.09))) * 0.45); // clumps catching the light
	// the game trail: packed earth winding along, just this side of the line
	float wig = 8.0 * sin(world.x * 0.006) + 5.0 * sin(world.x * 0.017);
	float path = trail * smoothstep(4.0, 10.0, d - wig) * smoothstep(46.0, 36.0, d - wig);
	col = mix(col, mix(soil_top.rgb * 1.45, soil_top.rgb * 1.2, vnoise(vec2(u * 0.08, v * 0.2))), path * (1.0 - snow));
	// stones scattered about
	vec2 sc = vec2(u * 0.04, v * 0.06);
	vec2 cell = floor(sc);
	float stone = step(0.972, hash(cell)) * smoothstep(0.4, 0.28, distance(fract(sc) * vec2(1.0, 1.4), vec2(0.5, 0.7)));
	vec3 rock = vec3(0.56, 0.54, 0.5) * (0.8 + 0.35 * hash(cell + 3.1));
	col = mix(col, rock * mix(1.1, 0.8, fract(sc.y) ), stone);
	// the wind going over the grass in waves, the bent blades catching the light
	float wave = pow(max(sin(u * 0.0035 - TIME * (1.2 + 2.0 * wind) * wind_dir + fbm(vec2(u * 0.001, v * 0.01)) * 4.0), 0.0), 6.0);
	col *= 1.0 + wave * wind * 0.22 * (1.0 - snow) * (1.0 - smoothstep(0.62, 0.72, patches));
	// wildflowers: drifts of blue lupine, yellow balsamroot, red paintbrush, white yarrow
	float meadow = smoothstep(0.45, 0.7, fbm(vec2(u * 0.0025, v * 0.012) + 71.0)) * bloom * UV.x * (1.0 - snow);
	vec2 fcell = floor(vec2(u * 0.12, v * 0.2));
	float fl = step(0.72 - meadow * 0.35, hash(fcell + 9.0)) * step(0.02, meadow) * smoothstep(0.42, 0.2, distance(fract(vec2(u * 0.12, v * 0.2)), vec2(0.5)));
	float which = hash(fcell + 4.4) + fbm(vec2(u * 0.002, 3.0)) * 0.6; // one colour tends to hold a patch
	vec3 petal = which < 0.5 ? vec3(0.42, 0.45, 0.85) : (which < 0.85 ? vec3(0.95, 0.8, 0.25) : (which < 1.05 ? vec3(0.85, 0.28, 0.2) : vec3(0.95, 0.94, 0.9)));
	col = mix(col, petal, fl * (1.0 - path) * (1.0 - stone));
	// after rain: the ground darker, puddles in the hollows showing the sky, rings when it's raining
	col *= 1.0 - 0.28 * wet * (1.0 - snow);
	float hollow = fbm(vec2(u * 0.011, v * 0.05) + 31.0);
	float puddle = smoothstep(0.66, 0.7, hollow) * smoothstep(0.35, 0.8, wet) * (1.0 - snow);
	vec3 pool = mix(haze_color.rgb * vec3(0.62, 0.68, 0.76), col * 0.5, 0.3); // the sky in it, darker than the sky
	pool = mix(pool, col * 0.55, smoothstep(0.7, 0.66, hollow) * 0.0 + smoothstep(0.672, 0.66, hollow)); // a dark wet rim
	vec2 rc = vec2(u * 0.05, v * 0.12 + floor(TIME * 1.3) * 0.37);
	float ring = smoothstep(0.08, 0.0, abs(distance(fract(rc), vec2(0.5)) - fract(TIME * 1.3) * 0.45)) * step(0.55, hash(floor(rc) + floor(TIME * 1.3)));
	pool += ring * rain_k * 0.25;
	col = mix(col, pool, puddle);
	// frost: pale over the grass and glinting, before the sun gets to it
	vec3 rime = mix(vec3(0.78, 0.82, 0.86), vec3(0.92, 0.94, 0.97), grain);
	col = mix(col, rime, frost * (0.2 + 0.35 * smoothstep(0.45, 0.8, grain)) * (1.0 - stone)); // rime on the blades, the ground showing through
	col += step(0.99, hash(floor(vec2(u * 0.7, v * 0.7)))) * frost * 0.35;
	// snow over it all, blue in the hollows, glinting
	float drift = fbm(vec2(u * 0.006, v * 0.05));
	vec3 snowc = mix(vec3(0.76, 0.82, 0.92), vec3(0.95, 0.97, 1.0), smoothstep(0.35, 0.65, drift));
	snowc += step(0.992, hash(floor(vec2(u * 0.6, v * 0.6)))) * 0.25 * sun_k;
	col = mix(col, snowc, clamp(snow * 1.1, 0.0, 1.0));
	col = creek_out(creeks.x, creeks.y, d, world, col, persp, v);
	col = creek_out(creeks.z, creeks.w, d, world, col, persp, v);
	// nearer is darker (in the shade of the near trees), the far edge hazier and sunlit
	col *= mix(1.0, 0.7, smoothstep(40.0, 320.0, d));
	col = mix(col, haze_color.rgb, 0.16 * (1.0 - smoothstep(0.0, 45.0, d)));
	col += sun_col.rgb * sun_k * 0.1 * (1.0 - smoothstep(0.0, 8.0, d));
	// underground: the cut earth
	vec3 cut = mix(soil_top.rgb, soil_deep.rgb, smoothstep(14.0, 320.0, d));
	cut = mix(top * 0.75, cut, smoothstep(0.0, 14.0, d));
	COLOR = vec4(mix(col, cut, under), 1.0);
}
