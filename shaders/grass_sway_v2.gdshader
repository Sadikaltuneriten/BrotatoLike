shader_type canvas_item;

// ── Wind-Parameter ────────────────────────────────────────────────────────────
uniform vec4  u_wind_dir   = vec4(1.0, 0.0, 0.0, 0.0);  // xy = Richtung, z = Stärke
uniform float u_wind_speed = 1.2;
uniform float u_sway_amp   = 0.12;          // Grund-Amplitude des Wehens
uniform float u_sway_freq  = 0.9;

// ── Spieler-Fußabdruck ────────────────────────────────────────────────────────
uniform vec2 u_player_pos  = vec2(0.5, 0.5);          // Normierte Spielerposition
uniform vec3 u_player_move = vec3(0.0, 0.0, 0.0);     // xy = Richtung, z = Geschw.

// ── Farben ────────────────────────────────────────────────────────────────────
uniform vec4 u_color_low  = vec4(0.08, 0.20, 0.05, 1.0);
uniform vec4 u_color_high = vec4(0.20, 0.45, 0.12, 1.0);

// ── Grasdichte / Blade-Größe ──────────────────────────────────────────────────
uniform float u_blade_density = 30.0;
uniform float u_blade_width   = 0.10;

// ── Hilfsfunktionen (müssen VOR fragment deklariert werden) ───────────────────
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float blend_hash(float a, float b) {
	return hash(a * 13.31 + b * 7.77);
}

// ── Haupt-Rendering: erzeugt Gras-Blades über die gesamte Fläche ───────────────
void fragment() {
	float t = TIME;
	vec2 uv = UV;

	// 1) Grundfarbe: unten dunkel, oben hell (Gras-Verlauf)
	float v = uv.y;
	vec3 grass_color = mix(u_color_low.rgb, u_color_high.rgb, pow(v, 0.8));

	// 2) Blade-Muster: feine vertikale Streifen (Grasblätter)
	float cell = uv.x * u_blade_density;
	float col  = floor(cell);
	float local_x = fract(cell);
	float rand_col = hash(col);

	// 3) Wehen: jedes Blatt weht unabhängig mit eigener Phase
	float phase = col * 1.7 + t * u_wind_speed * u_sway_freq;
	// Wind wirkt stärker oben (Blade-Spitzen) als unten (Boden)
	float height_factor = pow(v, 1.5);
	float sway = sin(phase + rand_col * 6.2831) * u_sway_amp * height_factor;
	// Zweite, langsamere Welle für natürliche Bewegung
	sway += sin(phase * 0.45 + uv.y * 4.0) * u_sway_amp * 0.4 * height_factor;
	sway *= u_wind_dir.x;

	// Blade-Kurve
	float shifted_x = local_x + sway * 2.0;

	// 4) Spieler-Fußabdruck: Gras wird in Bewegungsrichtung weggedrückt
	float speed = u_player_move.z;
	vec2 diff = uv - u_player_pos;
	// y-Flip: in UV ist oben=0, in der Welt ist unten=0
	diff.y = -diff.y;
	float dist = length(diff);
	// Fußabdruck-Glocke: nah am Spieler stark, mit Abstand abgeflacht
	float foot = exp(-dist * dist * 22.0);
	// In Bewegungsrichtung schieben (Vorzeichen anhand x-Verlauf)
	float dir_sign = step(0.0, u_player_move.x);
	float bend = foot * clamp(speed * 0.004, 0.0, 0.5) * height_factor;
	shifted_x += bend * (dir_sign - 0.5) * 2.0;

	// 5) Blade-Rand: abgerundete Streifen (0 am Rand, 1 in der Mitte)
	float blade = smoothstep(0.0, u_blade_width, shifted_x)
		* smoothstep(1.0, 1.0 - u_blade_width, shifted_x);

	// 6) Schattierung + Grain
	float shade = mix(0.75, 1.25, blend_hash(col, uv.y));
	float light = shade * mix(0.8, 1.1, v);
	grass_color *= light;
	grass_color += (hash(uv.x * 900.0 + uv.y * 450.0) - 0.5) * 0.04;

	// 7) Kanten-Ausblenden (natürlicher Rand oben/unten)
	float edge = smoothstep(0.0, 0.04, v) * smoothstep(1.0, 0.92, v);
	float coverage = blade * edge;

	// 8) Dazwischen liegt dunkler Boden
	vec3 floor_color = u_color_low.rgb * 0.35;
	vec3 final_color = mix(floor_color, grass_color, coverage);

	COLOR = vec4(final_color, 1.0);
}
