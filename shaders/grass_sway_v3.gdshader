shader_type canvas_item;

// ── Spieler-Fußabdruck ────────────────────────────────────────────────────────
uniform vec2 u_player_pos  = vec2(0.5, 0.5);
uniform vec3 u_player_move = vec3(0.0, 0.0, 0.0);

// ── Gras-Farben (hell und klar) ───────────────────────────────────────────────
uniform vec3 u_color_low  = vec3(0.10, 0.40, 0.08);
uniform vec3 u_color_high = vec3(0.35, 0.75, 0.18);
uniform vec3 u_ground     = vec3(0.12, 0.28, 0.06);

// ── Grasstruktur ──────────────────────────────────────────────────────────────
uniform float u_sway_amp   = 0.10;
uniform float u_sway_speed = 1.5;
uniform float u_tuft_size  = 0.06;  // Rastergröße der Grasbüschel

// ── Hilfsfunktionen ───────────────────────────────────────────────────────────
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// ── Fragment: ein klar sichtbares, wehendes Gras ──────────────────────────────
void fragment() {
	float t = TIME;
	vec2 uv = UV;

	// 1) Boden-Verlauf (leicht hell/dunkel pro Zelle)
	float cell = floor(uv / u_tuft_size);
	float rnd = hash(cell.x * 57.0 + cell.y * 131.0);
	vec3 ground = mix(u_ground, u_color_low, 0.5 + rnd * 0.5);

	// 2) Grasbüschel: in jedem Raster-Feld ein paar "Blades" (vertikale Striche)
	//    Lokale Koordinate im Feld
	vec2 local = fract(uv / u_tuft_size) * 2.0 - 1.0;

	// 3) Wehen: horizontale Auslenkung, abhängig von Höhe und Zeit
	float sway = sin(t * u_sway_speed + cell.x * 1.3 + cell.y * 2.1) * u_sway_amp;
	sway += sin(t * u_sway_speed * 0.6 + rnd * 6.2831) * u_sway_amp * 0.5;

	// Spieler-Fußabdruck: Gras in Bewegungsrichtung drücken
	float speed = u_player_move.z;
	vec2 p = uv - u_player_pos;
	p.y = -p.y;
	float foot = exp(-length(p) * length(p) * 25.0);
	float dir_sign = step(0.0, u_player_move.x);
	sway += foot * clamp(speed * 0.004, 0.0, 0.4) * (dir_sign - 0.5);

	// 4) Blades: 3 Striche pro Feld, die sich nach "sway" neigen
	float blade = 0.0;
	for (int i = 0; i < 3; i++) {
		float xi = -0.5 + float(i) * 0.5;        // -0.5, 0.0, 0.5
		// Der Strich biegt sich nach oben (local.y > 0)
		float bend = sway * clamp(local.y * 0.5 + 0.5, 0.0, 1.0);
		float dx = local.x - xi + bend;
		blade = max(blade, 1.0 - smoothstep(0.0, 0.10, abs(dx)));
	}

	// 5) Strich wird mit Höhe dünner (Grasspitzen)
	blade *= smoothstep(0.0, 0.15, local.y * 0.5 + 0.5);

	// 6) Farbe: Gras heller als Boden, leicht variiert
	vec3 grass_col = mix(u_color_low, u_color_high, local.y * 0.5 + 0.5 + rnd * 0.2);
	grass_col *= 0.9 + rnd * 0.3;

	// 7) Mischen Boden + Gras
	vec3 col = mix(ground, grass_col, blade);

	// Leichte Vignette, damit Ecken nicht komplett flach wirken
	col *= 0.85 + 0.15 * (1.0 - length(uv - 0.5));

	COLOR = vec4(col, 1.0);
}
