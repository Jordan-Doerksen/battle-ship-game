shader_type canvas_item;
// Screen patina — 1:1 port of the mockup's CSS overlay (scanlines + vignette). Pure cosmetics on a
// full-screen ColorRect in the HUD CanvasLayer; touches nothing but pixels.

void fragment() {
	float scan = (mod(FRAGCOORD.y, 3.0) < 1.0) ? 0.07 : 0.0;
	vec2 uv = UV - vec2(0.5);
	float vig = smoothstep(0.275, 0.62, length(uv * vec2(1.15, 1.0))) * 0.55;
	COLOR = vec4(0.008, 0.039, 0.055, clamp(scan + vig, 0.0, 0.85));
}
