shader_type canvas_item;
// Heat shimmer: over hot dry ground at midday the view wavers, most along the ground and the
// near horizon. Only switched on when there's heat to show (it reads the screen).

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amount = 0.0;

void fragment() {
	float band = smoothstep(0.3, 0.5, SCREEN_UV.y) * smoothstep(1.0, 0.7, SCREEN_UV.y);
	float wob = sin(SCREEN_UV.y * 190.0 + TIME * 5.0) + 0.6 * sin(SCREEN_UV.y * 67.0 - TIME * 3.1 + SCREEN_UV.x * 9.0);
	vec2 off = vec2(wob * 0.0014, wob * 0.0004) * amount * band;
	COLOR = vec4(texture(screen, SCREEN_UV + off).rgb, 1.0);
}
