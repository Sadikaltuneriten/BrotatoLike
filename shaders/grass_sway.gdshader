shader_type canvas_item;

// ── Wind-Parameter (können pro Instanz leicht variieren) ──────────────────────
uniform vec4 u_wind_dir     = vec4(1.0, 0.0, 0.0, 0.0);  // xy = Richtung, zw = Stärke
uniform float u_wind_speed = 1.2;
uniform float u_sway_amp   = 0.12;          // Grund-Amplitude des Wehens
uniform float u_sway_freq  = 0.9;           // Wie schnell das Gras weht

// ── Spieler-Fußabdruck ────────────────────────────────────────────────────────
// Position des Spielers in normierter Screen-Koordinate (0..1)
uniform vec2  u_player_pos    = vec2(0.5, 0.5);
// Aktuelle Bewegungsrichtung des Spielers (x,y) + Geschwindigkeit (z, px/s)
uniform vec3  u_player_move   = vec3(0.0, 0.0, 0.0);

// ── Farben ────────────────────────────────────────────────────────────────────
uniform vec4 u_color_low    : source_color = vec4(0.08, 0.20, 0.05, 1.0);
uniform vec4 u_color_high   : source_color = vec4(0.20, 0.45, 0.12, 1.0);

// ── Grasdichte / Blade-Größe (in UV-Raum) ─────────────────────────────────────
uniform float u_blade_density = 30.0;
uniform float u_blade_width   = 0.10;

// ── Kleine Noise-Funktion (billiger Wert-Noise) ───────────────────────────────
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// Hilfsfunktion: Mischungszahl für Schattierung
float blend_hash(float a, float b) {
	return hash(a * 13.31 + b * 7.77);
}

// Haupt-Rendering: erzeugt Gras-Blades über die gesamte Fläche
void fragment() {
	float t = TIME;
	vec2 uv = UV;

	// 1) Grundfarbe: unten dunkel, oben hell (Gras-Vertikalverlauf)
	float v = uv.y;
	vec3 grass_color = mix(u_color_low.rgb, u_color_high.rgb, pow(v, 0.8));

	// 2) Blade-Muster: feine vertikale Streifen (Grasblätter)
	float cell = uv.x * u_blade_density;
	float col  = floor(cell);
	float local_x = fract(cell);          // 0..1 innerhalb einer Blade
	float rand_col = hash(col);

	// 3) Wehen: jede Blase weht unabhängig mit eigener Phase
	float phase = col * 1.7 + t * u_wind_speed * u_sway_freq;
	float height_factor = pow(v, 1.5);
	float sway = sin(phase + rand_col * 6.2831) * u_sway_amp * height_factor;
	sway += sin(phase * 0.45 + uv.y * 4.0) * u_sway_amp * 0.4 * height_factor;
	sway *= u_wind_dir.x;

	float curve = sway * height_factor;
	float shifted_x = local_x + curve * 2.0;

	float blade = smoothstep(0.0, u_blade_width, shifted_x)
		- smoothstep(1.0, 1.0 - u_blade_width, shifted_x);

	// 4) Spieler-Fußabdruck: Gras wird in Bewegungsrichtung weggedrückt
	vec2 move_dir = normalize(u_player_move.xy + vec2(0.0001, 0.0));
	float speed = u_player_move.z;
	vec2 diff = uv - u_player_pos;
	diff.y = -diff.y;
	float dist = length(diff);
	float foot_influence = exp(-dist * dist * 22.0);
	float push = foot_influence * clamp(speed * 0.004, 0.0, 0.5);
	vec2 push_dir = move_dir;
	push_dir.y = -push_dir.y;            
	float bend = push * height_factor;
	shifted_x += bend * (dot(diff.xy, vec2(1.0, 0.0)) > 0.0 ? 1.0 : -1.0) * 2.0;
	blade = smoothstep(0.0, u_blade_width, shifted_x)
		- smoothstep(1.0, 1.0 - u_blade_width, shifted_x);

	// 5) Beleuchtung / Schattierung
	float shade = mix(0.75, 1.25, blend_hash(col, uv.y));
	float light = shade * mix(0.8, 1.1, v);
	grass_color *= light;

	// 6) Alpha
	float edge = smoothstep(0.0, 0.04, v) * smoothstep(1.0, 0.92, v);
	float blade_alpha = blade * edge;

	// 7) Deckungsfläche
	float coverage = blade_alpha * step(0.15, blade);
	float floor_dark = 0.35;
	vec3 final_color = mix(vec3(u_color_low.rgb * floor_dark), grass_color, coverage);

	final_color += (hash(uv.x * 900.0 + uv.y * 450.0) - 0.5) * 0.04;

	COLOR = vec4(final_color, 1.0);
}