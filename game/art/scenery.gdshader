shader_type canvas_item;
// Shared by all scenery polygons: wind sway (UV.y: 1 = base, 0 = tip), seasons and depth haze.
// UV.x tags what a polygon is (SceneryArt.PLAIN/GRASS/LEAF/SNOW/GROUND/WATER): 0 plain,
// 0.5 grass/fern, 1 deciduous leaves, 2 snow cap, 3 open ground, 4 water.

global uniform float wind;
global uniform float wind_dir;
global uniform vec4 haze_color;
global uniform float snow; // 0..1 how snowed-in the world looks
global uniform float autumn; // 0..1 leaves and grass turned
global uniform float bare; // 0..1 deciduous leaves fallen
global uniform float ice; // 0..1 creek frozen
global uniform float frost; // white frost on grass and open ground, cold mornings
global uniform float wet; // rained on: things a little darker
global uniform float sun_dir; // -1 the sun's to the left .. 1 to the right
global uniform float sun_k; // how strongly it's shining
global uniform vec4 sun_col;
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform float sway = 0.0; // px of tip movement per unit of wind
uniform float shade_px = 110.0; // how wide a tree is here, for lighting its sides
varying vec2 local;

const vec3 SNOW = vec3(0.93, 0.95, 0.99);
const vec3 GOLD = vec3(0.86, 0.66, 0.2);
const vec3 STRAW = vec3(0.62, 0.55, 0.36);

void vertex() {
	local = VERTEX;
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float tip = 1.0 - UV.y;
	float gust = sin(TIME * 1.7 + world.x * 0.004) + 0.4 * sin(TIME * 3.1 + world.x * 0.011);
	gust += 1.6 * pow(max(sin(world.x * 0.0035 - TIME * (1.2 + 2.0 * wind) * wind_dir), 0.0), 6.0) * step(0.25, UV.x) * step(UV.x, 0.75); // waves running through the grass
	VERTEX.x += gust * wind * sway * tip * tip * (1.0 - snow * 0.6); // laden boughs sway less
}

void fragment() {
	float kind = UV.x;
	if (kind > 5.5) { // far ranges: haze gathers toward their feet
		COLOR.rgb = mix(COLOR.rgb, haze_color.rgb, (1.0 - haze) * 0.6 * smoothstep(0.0, 0.16, UV.y));
		COLOR.rgb += sun_col.rgb * sun_k * 0.05;
	} else if (kind > 4.5) { // mountain faces: in shadow when turned from the sun (UV.y 0 faces left, 1 right)
		float facing = UV.y * 2.0 - 1.0;
		COLOR.a *= clamp(0.2 - facing * sun_dir * (0.3 + 0.35 * sun_k), 0.0, 0.6);
	} else {
		if (kind < 1.5) { // a tree, bush or rock: the sunny side warm and light, the far side cool
			float side = clamp(local.x / shade_px, -1.0, 1.0) * sun_dir;
			float base = UV.y < 0.999 ? UV.y * UV.y : 0.35;
			COLOR.rgb *= 1.0 + (0.16 * side * (0.3 + sun_k) - 0.2 * base);
			COLOR.rgb += sun_col.rgb * 0.1 * max(side, 0.0) * sun_k * (1.0 - base);
		}
		if (kind > 3.5) {
			vec3 frozen = mix(vec3(0.72, 0.82, 0.88), SNOW, snow * step(0.6, ice));
			COLOR.rgb = mix(COLOR.rgb, frozen, smoothstep(0.3, 0.8, ice));
		} else if (kind > 2.5) {
			COLOR.rgb = mix(COLOR.rgb, SNOW * 0.94, snow * 0.9);
			COLOR.rgb = mix(COLOR.rgb, vec3(0.8, 0.83, 0.87), frost * 0.5 * (1.0 - snow));
		} else if (kind > 1.5) {
			COLOR.rgb = SNOW;
			COLOR.a *= snow;
		} else if (kind > 0.75) {
			COLOR.rgb = mix(COLOR.rgb, GOLD * (0.8 + 0.3 * COLOR.g), autumn * 0.85);
			COLOR.a *= 1.0 - bare;
		} else if (kind > 0.25) {
			COLOR.rgb = mix(COLOR.rgb, STRAW * (0.7 + 0.5 * COLOR.g), autumn * 0.7);
			COLOR.rgb = mix(COLOR.rgb, vec3(0.82, 0.85, 0.89), frost * 0.6 * (1.0 - UV.y)); // rimed tips
		}
	}
	COLOR.rgb *= 1.0 - 0.12 * wet * step(kind, 1.5);
	COLOR.rgb = mix(COLOR.rgb, haze_color.rgb, haze);
}
