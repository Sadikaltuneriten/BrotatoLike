shader_type canvas_item;

uniform vec2 u_player_pos = vec2(0.5, 0.5);
uniform vec3 u_player_move = vec3(0.0, 0.0, 0.0);
uniform float u_sway_amp = 0.12;
uniform float u_sway_speed = 1.5;
uniform float u_tuft = 0.06;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
    float t = TIME;
    vec2 uv = UV;

    // Boden-Zelle
    vec2 cell = floor(uv / u_tuft);
    float rnd = hash(cell.x * 57.0 + cell.y * 131.0);

    // Bodenfarbe
    vec3 ground = mix(vec3(0.10, 0.30, 0.06), vec3(0.18, 0.45, 0.10), rnd);

    // Lokale Position im Raster
    vec2 local = fract(uv / u_tuft) * 2.0 - 1.0;

    // Wehen
    float sway = sin(t * u_sway_speed + cell.x * 1.3 + cell.y * 2.1) * u_sway_amp;
    sway += sin(t * u_sway_speed * 0.6 + rnd * 6.2831) * u_sway_amp * 0.5;

    // Spieler-Fußabdruck
    float speed = u_player_move.z;
    vec2 p = uv - u_player_pos;
    p.y = -p.y;
    float foot = exp(-length(p) * length(p) * 25.0);
    float dir_sign = step(0.0, u_player_move.x);
    sway += foot * clamp(speed * 0.004, 0.0, 0.4) * (dir_sign - 0.5);

    // 3 Grasbläder pro Feld
    float blade = 0.0;
    for (int i = 0; i < 3; i++) {
        float xi = -0.5 + float(i) * 0.5;
        float bend = sway * clamp(local.y * 0.5 + 0.5, 0.0, 1.0);
        float dx = local.x - xi + bend;
        blade = max(blade, 1.0 - smoothstep(0.0, 0.12, abs(dx)));
    }

    // Spitze dünner
    blade *= smoothstep(0.0, 0.15, local.y * 0.5 + 0.5);

    // Grasfarbe (hell)
    vec3 grass_col = mix(vec3(0.15, 0.55, 0.10), vec3(0.40, 0.85, 0.20), local.y * 0.5 + 0.5 + rnd * 0.2);
    grass_col *= 0.85 + rnd * 0.3;

    // Mischen
    vec3 col = mix(ground, grass_col, blade);
    col *= 0.85 + 0.15 * (1.0 - length(uv - 0.5));

    COLOR = vec4(col, 1.0);
}
