shader_type canvas_item;
// Shared by all scenery polygons: wind sway (UV.y: 1 = base, 0 = tip), seasons and depth haze.
// UV.x tags what a polygon is (SceneryArt.PLAIN/GRASS/LEAF/SNOW/GROUND/WATER): 0 plain,
// 0.5 grass/fern, 1 deciduous leaves, 2 snow cap, 3 open ground, 4 water.

global uniform float wind;
global uniform vec4 haze_color;
global uniform float snow; // 0..1 how snowed-in the world looks
global uniform float autumn; // 0..1 leaves and grass turned
global uniform float bare; // 0..1 deciduous leaves fallen
global uniform float ice; // 0..1 creek frozen
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform float sway = 0.0; // px of tip movement per unit of wind

const vec3 SNOW = vec3(0.93, 0.95, 0.99);
const vec3 GOLD = vec3(0.86, 0.66, 0.2);
const vec3 STRAW = vec3(0.62, 0.55, 0.36);

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float tip = 1.0 - UV.y;
	float gust = sin(TIME * 1.7 + world.x * 0.004) + 0.4 * sin(TIME * 3.1 + world.x * 0.011);
	VERTEX.x += gust * wind * sway * tip * tip * (1.0 - snow * 0.6); // laden boughs sway less
}

void fragment() {
	float kind = UV.x;
	if (kind > 3.5) {
		vec3 frozen = mix(vec3(0.72, 0.82, 0.88), SNOW, snow * step(0.6, ice));
		COLOR.rgb = mix(COLOR.rgb, frozen, smoothstep(0.3, 0.8, ice));
	} else if (kind > 2.5) {
		COLOR.rgb = mix(COLOR.rgb, SNOW * 0.94, snow * 0.9);
	} else if (kind > 1.5) {
		COLOR.rgb = SNOW;
		COLOR.a *= snow;
	} else if (kind > 0.75) {
		COLOR.rgb = mix(COLOR.rgb, GOLD * (0.8 + 0.3 * COLOR.g), autumn * 0.85);
		COLOR.a *= 1.0 - bare;
	} else if (kind > 0.25) {
		COLOR.rgb = mix(COLOR.rgb, STRAW * (0.7 + 0.5 * COLOR.g), autumn * 0.7);
	}
	COLOR.rgb = mix(COLOR.rgb, haze_color.rgb, haze);
}
