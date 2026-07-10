shader_type canvas_item;
// C9 THE LIVING SEA — the approved mockup's band+glint recipe (design/living-sea.html, direction B)
// as one fullscreen pass on a screen-space ColorRect (CanvasLayer -1, behind the world layer).
// World-space math from cam/zoom uniforms so the sea is anchored to the world, not the screen.
// Main.gd feeds the uniforms each frame (cam_pos, zoom, sea_time, hf_fade); the sea tables live
// in config/field.tres. sea_time simply stops advancing under reduced motion — nothing else needed.

uniform vec2 cam_pos = vec2(0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float zoom = 0.85;
uniform float sea_time = 0.0;
uniform float amp = 0.95;        // band strength   (field.tres sea_amp)
uniform float drift = 1.4;       // drift speed     (field.tres sea_drift)
uniform float band_scale = 1.15; // spatial scale   (field.tres sea_scale)
uniform float glint = 0.75;      // glint intensity (field.tres glint_intensity)
uniform float hf_fade = 1.0;     // high-frequency fade, CPU-computed from zoom (C10 contract)

const vec3 SEA = vec3(0.039, 0.118, 0.157);      // #0A1E28 — the C1 sea, unchanged
const vec3 CREST = vec3(0.243, 0.439, 0.502);    // lifted, cool lit water
const vec3 TROUGH = vec3(0.012, 0.039, 0.059);   // sunk, darker water
const vec3 FOAM = vec3(0.894, 0.941, 0.949);     // #E4F0F2

float h2(vec2 p) {   // wrap the lattice before hashing — huge world coords murder sin() precision
	vec2 q = mod(p, 289.0);
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), u.x),
	           mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// One band layer = a sum of three sines on integer wavevectors (seamless by construction),
// crest side lifts toward CREST, trough side sinks toward TROUGH — the mockup tile, analytic.
float band_h(vec2 w, float per, vec2 scroll, vec3 k1, vec3 k2, vec3 k3) {
	vec2 p = (w - scroll) * (TAU / per);
	return k1.z * sin(k1.x * p.x + k1.y * p.y + 0.7)
	     + k2.z * sin(k2.x * p.x + k2.y * p.y + 2.9)
	     + k3.z * sin(k3.x * p.x + k3.y * p.y + 5.1);
}

void fragment() {
	vec2 world = cam_pos + (UV - 0.5) * viewport_size / zoom;
	vec3 col = SEA;
	// layer 1 — the broad diagonal swell (period ~1180u), the long heavy roll
	float per1 = 512.0 * 2.3 * band_scale;
	float h1 = band_h(world, per1, vec2(8.5, 8.5) * sea_time * drift,
		vec3(2.0, 1.0, 0.55), vec3(1.0, 2.0, 0.30), vec3(3.0, -1.0, 0.15));
	float a1 = amp * (h1 > 0.0
		? smoothstep(0.18, 0.95, h1) * 0.16
		: smoothstep(0.18, 0.95, -h1) * 0.20);
	col = mix(col, h1 > 0.0 ? CREST : TROUGH, a1);
	// layer 2 — finer counter-diagonal chop riding on top; fades out as C10 pulls the camera back
	float per2 = 512.0 * 1.15 * band_scale;
	float h2v = band_h(world, per2, vec2(-10.0, 14.0) * sea_time * drift,
		vec3(4.0, 3.0, 0.50), vec3(3.0, -4.0, 0.30), vec3(6.0, 2.0, 0.20));
	float a2 = amp * 0.8 * (0.35 + 0.65 * hf_fade) * (h2v > 0.0
		? smoothstep(0.18, 0.95, h2v) * 0.10
		: smoothstep(0.18, 0.95, -h2v) * 0.12);
	col = mix(col, h2v > 0.0 ? CREST : TROUGH, a2);
	// glints — a slow low-frequency envelope picks WHERE the sea catches light, a counter-scrolled
	// high-frequency grain thresholded near its peaks makes the catches TINY (the mockup's 3-px
	// flecks, per-pixel). Soft edges, never hard sparkle; the whole layer fades with the C10 zoom.
	if (glint > 0.02) {
		float env = smoothstep(0.55, 0.85, vnoise(world * 0.012 + vec2(sea_time * 0.55, sea_time * 0.40)));
		float grain = vnoise(world * 0.09 + vec2(-sea_time * 0.45, sea_time * 0.35) * 4.0);
		float m = smoothstep(0.82, 0.94, grain) * env * glint * hf_fade;
		col = mix(col, FOAM, m * 0.4);
	}
	COLOR = vec4(col, 1.0);
}
