shader_type canvas_item;
// Shared by all scenery polygons: wind sway (UV.y: 1 = base, 0 = tip) and depth haze.

global uniform float wind;
global uniform vec4 haze_color;
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform float sway = 0.0; // px of tip movement per unit of wind

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float tip = 1.0 - UV.y;
	float gust = sin(TIME * 1.7 + world.x * 0.004) + 0.4 * sin(TIME * 3.1 + world.x * 0.011);
	VERTEX.x += gust * wind * sway * tip * tip;
}

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, haze_color.rgb, haze);
}
