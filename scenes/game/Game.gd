extends Node2D

const PLAYER_SCENE  = preload("res://scenes/player/Player.tscn")
const ENEMY_SCENE   = preload("res://scenes/enemies/Enemy.tscn")
const BOMB_SCENE    = preload("res://scenes/bombs/Bomb.tscn")
const COMPANION_SCENE = preload("res://scenes/companion/Companion.tscn")
const WaveRules    = preload("res://scripts/logic/WaveRules.gd")
const ShopRules    = preload("res://scripts/logic/ShopRules.gd")
const LevelUpRules = preload("res://scripts/logic/LevelUpRules.gd")

var player: Node2D = null
var companion: Node2D = null
var wave_timer  := 0.0
var spawn_timer := 0.0
var in_shop     := false
var game_over   := false
var shop_layer: CanvasLayer = null
var _shop_items: Array = []  # [{btn, upgrade}]
var level_up_layer: CanvasLayer = null
var _pending_levels: Array[int] = []
var pause_layer: CanvasLayer = null
var is_paused := false

# ── Wave-Musik ───────────────────────────────────────────────────────────────────
var _music_player: AudioStreamPlayer = null
var music_volume_db: float = 0.0       # 0 dB = laut, -80 dB = stumm
const MUSIC_DIR := "res://sound_sfx/lvl_musik"
var _vol_percent_label: Label = null    # Live-Anzeige im Pause-Menü




var hud_health: Label
var hud_wave:   Label
var hud_gold:   Label
var hud_timer:  Label
var hud_level:  Label
var hud_xp_bar: ProgressBar
var hud_bomb:   Label

func _ready() -> void:
	GameState.reset()
	get_tree().paused = false
	_setup_background()
	_setup_hud()
	_setup_music()


	player = PLAYER_SCENE.instantiate()
	player.died.connect(_on_player_died)
	add_child(player)
	player.global_position = get_viewport_rect().size / 2

	# Companion (Begleitfigur) instanzieren
	companion = COMPANION_SCENE.instantiate()
	add_child(companion)
	if companion.has_method("setup"):
		companion.setup(player)

	GameState.health_changed.connect(_on_health_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	if LevelUpRules.is_enabled():
		GameState.leveled_up.connect(_on_leveled_up)

	_start_wave()

func _process(delta: float) -> void:
	if in_shop:
		return
	wave_timer  -= delta
	spawn_timer -= delta

	hud_timer.text = "⏱ %d" % WaveRules.display_seconds(wave_timer)

	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = WaveRules.spawn_interval(GameState.wave)

	if WaveRules.is_wave_over(wave_timer):
		_end_wave()

func _unhandled_input(event: InputEvent) -> void:
	# Pause-Menü mit ESC oder Controller-Start/Back umschalten
	var pause_pressed := false
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			pause_pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_BACK:
			pause_pressed = true

	if pause_pressed and not game_over:
		# Wenn bereits ein anderes Overlay (Shop / Level-Up) aktiv ist, ignorieren
		if in_shop or level_up_layer != null:
			return
		if is_paused:
			_resume_game()
		else:
			_pause_game()

	# Bomben platzieren mit Q (Tastatur) oder B (Controller)
	if game_over or in_shop or level_up_layer != null or is_paused:
		return
	var bomb_pressed := false
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			bomb_pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			bomb_pressed = true

	if bomb_pressed:
		_place_bomb()

# ── Wave flow ────────────────────────────────────────────────────────────────

func _start_wave() -> void:
	in_shop = false
	wave_timer  = WaveRules.WAVE_DURATION
	spawn_timer = WaveRules.FIRST_SPAWN_DELAY
	hud_wave.text = "Wave %d" % GameState.wave
	# Bomben-Reset am Welle-Start
	GameState.bomb_count = 0
	_update_bomb_hud()
	# Zufälligen Track für diese Welle abspielen
	_play_random_wave_music()

func _end_wave() -> void:
	wave_timer = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	# Bestehende Bomben entfernen
	for bomb in get_tree().get_nodes_in_group("bombs"):
		bomb.queue_free()
	# Musik während der Pause stoppen
	_stop_wave_music()
	GameState.wave += 1
	_open_shop()


# ── Enemy spawning ───────────────────────────────────────────────────────────

func _spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	var vp    := get_viewport_rect().size
	var side  := randi() % 4
	var spawn_pos: Vector2 = [
		Vector2(randf_range(0.0, vp.x), -50.0),
		Vector2(randf_range(0.0, vp.x), vp.y + 50.0),
		Vector2(-50.0, randf_range(0.0, vp.y)),
		Vector2(vp.x + 50.0, randf_range(0.0, vp.y)),
	][side]
	enemy.global_position = spawn_pos
	add_child(enemy)

	var type := WaveRules.enemy_type_for_roll(randf())
	enemy.setup_type(type, GameState.wave)

# ── Shop ─────────────────────────────────────────────────────────────────────

func _open_shop() -> void:
	in_shop = true
	_shop_items = []

	shop_layer = CanvasLayer.new()
	add_child(shop_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	var title := Label.new()
	title.text = "SHOP  —  Wave %d Complete!" % (GameState.wave - 1)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var gold_label := Label.new()
	gold_label.text = "Gold: %d" % GameState.gold
	gold_label.add_theme_font_size_override("font_size", 19)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.20))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(gold_label)

	inner.add_child(HSeparator.new())

	var offers := ShopRules.roll_offers(GameState.UPGRADES)

	for upgrade in offers:
		var btn := Button.new()
		btn.text = "%s   [%d gold]" % [upgrade.label, upgrade.cost]
		btn.add_theme_font_size_override("font_size", 17)
		btn.disabled = not ShopRules.can_afford(GameState.gold, upgrade)
		_shop_items.append({"btn": btn, "upgrade": upgrade})
		inner.add_child(btn)

	# Connect after building the full array so each closure captures correct index
	for item in _shop_items:
		var captured_item = item
		item.btn.pressed.connect(func():
			_purchase_upgrade(captured_item, gold_label)
		)

	inner.add_child(HSeparator.new())

	var skip_btn := Button.new()
	skip_btn.text = "Continue to Wave %d  →" % GameState.wave
	skip_btn.add_theme_font_size_override("font_size", 17)
	skip_btn.pressed.connect(_close_shop)
	inner.add_child(skip_btn)

func _purchase_upgrade(item: Dictionary, gold_label: Label) -> void:
	var upgrade: Dictionary = item.upgrade
	var remaining := ShopRules.gold_after_purchase(GameState.gold, upgrade)
	if remaining < 0:
		return
	GameState.gold = remaining
	GameState.apply_upgrade(upgrade)
	_on_gold_changed(GameState.gold)
	gold_label.text = "Gold: %d" % GameState.gold

	var btn: Button = item.btn
	btn.disabled = true
	btn.text = "✓  " + btn.text

	if upgrade.stat == "max_health" and player and is_instance_valid(player):
		player.health = min(player.health + upgrade.value, GameState.stats.max_health)
		GameState.health_changed.emit(player.health, GameState.stats.max_health)

	for other in _shop_items:
		if not other.btn.disabled:
			other.btn.disabled = not ShopRules.can_afford(GameState.gold, other.upgrade)

func _close_shop() -> void:
	if shop_layer:
		shop_layer.queue_free()
		shop_layer = null
	_shop_items = []
	# Heilung nach jeder Welle (Brotato-Stil: volles Leben)
	if player and is_instance_valid(player):
		player.health = GameState.stats.max_health
		GameState.health_changed.emit(player.health, GameState.stats.max_health)
	_start_wave()
	_maybe_open_level_up()

# ── Level-up choice ──────────────────────────────────────────────────────────
# Pick 1 of 3 free upgrades from the shop pool on each level-up. Controlled by the
# project setting brotatolike/gameplay/level_up_choice (default on).

func _on_leveled_up(new_level: int) -> void:
	# Brotato-style: just queue level-ups, they will be shown at end of wave
	_pending_levels.append(new_level)

func _maybe_open_level_up() -> void:
	if game_over or in_shop or level_up_layer != null or _pending_levels.is_empty():
		return
	_open_level_up(_pending_levels.pop_front())
	# ── Wave-Musik ────────────────────────────────────────────────────────────────────
	# Lädt alle .mp3/.ogg/.wav aus MUSIC_DIR dynamisch, damit neue Songs automatisch
	# erkannt werden. Pro Welle wird ein zufälliger Track abgespielt.
func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.volume_db = music_volume_db
	add_child(_music_player)
	print("[Musik] AudioStreamPlayer erstellt und hinzugefügt")
func _apply_music_volume() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = music_volume_db

# Wird vom Slider aufgerufen: setzt Lautstärke + aktualisiert Prozent-Anzeige
func _on_music_volume_changed(new_value: float) -> void:
	music_volume_db = new_value
	_apply_music_volume()
	if _vol_percent_label:
		# dB -> Prozent (0 dB = 100%, -80 dB ≈ 0%)
		var pct := int((new_value + 80.0) / 80.0 * 100.0)
		_vol_percent_label.text = "🎵  Musik-Lautstärke:  %d%%" % pct




func _play_random_wave_music() -> void:
	print("[Musik] _play_random_wave_music aufgerufen")
	if _music_player == null:
		_setup_music()
	if _music_player == null:
		print("[Musik] _music_player ist null!")
		return

	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		print("[Musik] Ordner NICHT gefunden: %s (Fehler-Code: %d)" % [MUSIC_DIR, DirAccess.get_open_error()])
		return

	var files: Array = dir.get_files()
	# Nur Audio-Dateien filtern
	var audio_files: Array[String] = []
	for f in files:
		var ext: String = f.get_extension().to_lower()
		if ext == "mp3" or ext == "ogg" or ext == "wav":
			audio_files.append(f)

	print("[Musik] Gefundene Audiodateien (%d): %s" % [audio_files.size(), str(audio_files)])

	if audio_files.is_empty():
		print("[Musik] Keine Audiodateien gefunden!")
		return

	var picked: String = audio_files[randi() % audio_files.size()]
	var path := MUSIC_DIR + "/" + picked
	print("[Musik] Lade Stream: %s" % path)

	var stream = load(path)
	if stream == null:
		print("[Musik] Stream konnte NICHT geladen werden: %s" % path)
		return

	_music_player.stream = stream
	_music_player.play()
	print("[Musik] Abspielen gestartet: %s" % picked)

func _stop_wave_music() -> void:
	if _music_player == null:
		return
	_music_player.stop()


func _open_level_up(level: int) -> void:
	get_tree().paused = true

	level_up_layer = CanvasLayer.new()
	level_up_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(level_up_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.70)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_up_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_up_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	var title := Label.new()
	title.text = "LEVEL UP!  Level %d" % level
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var hint := Label.new()
	hint.text = "Choose one free upgrade"
	hint.add_theme_font_size_override("font_size", 17)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)

	inner.add_child(HSeparator.new())

	var first_button: Button = null
	for upgrade in LevelUpRules.roll_choices(GameState.UPGRADES):
		var btn := Button.new()
		btn.text = upgrade.label
		btn.add_theme_font_size_override("font_size", 18)
		var captured: Dictionary = upgrade
		btn.pressed.connect(func(): _choose_level_up(captured))
		inner.add_child(btn)
		if first_button == null:
			first_button = btn
	if first_button:
		first_button.grab_focus()

func _choose_level_up(upgrade: Dictionary) -> void:
	GameState.apply_upgrade(upgrade)
	if upgrade.stat == "max_health" and player and is_instance_valid(player):
		player.health = min(player.health + upgrade.value, GameState.stats.max_health)
		GameState.health_changed.emit(player.health, GameState.stats.max_health)
	if level_up_layer:
		level_up_layer.queue_free()
		level_up_layer = null
	get_tree().paused = false
	call_deferred("_maybe_open_level_up")

# ── Pause-Menu ────────────────────────────────────────────────────────────────

func _pause_game() -> void:
	is_paused = true
	get_tree().paused = true

	pause_layer = CanvasLayer.new()
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	# Hintergrund-Abdunkelung
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(bg)

	# Zentriertes Panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	# Titel
	var title := Label.new()
	title.text = "PAUSE"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)

	var hint := Label.new()
	hint.text = "Spiel gestoppt"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)

	inner.add_child(HSeparator.new())

	# ── Weiter-Button (aktuell einziger aktiver Button) ───────────────────────
	var resume_btn := Button.new()
	resume_btn.text = "▶  Weiter"
	resume_btn.add_theme_font_size_override("font_size", 20)
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.pressed.connect(_resume_game)
	inner.add_child(resume_btn)

	# ── Musik-Lautstärke-Slider ────────────────────────────────────────────────────
	_vol_percent_label = Label.new()
	_vol_percent_label.add_theme_font_size_override("font_size", 16)
	_vol_percent_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_vol_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_vol_percent_label)

	var vol_slider := HSlider.new()
	vol_slider.min_value = -80.0
	vol_slider.max_value = 0.0
	vol_slider.step = 1.0
	vol_slider.page = 1.0
	vol_slider.value = music_volume_db
	vol_slider.custom_minimum_size = Vector2(0, 28)
	vol_slider.value_changed.connect(_on_music_volume_changed)
	inner.add_child(vol_slider)
	_on_music_volume_changed(music_volume_db)  # Anzeige initial setzen


	var mainmenu_btn := Button.new()
	mainmenu_btn.text = "⌂  Hauptmenü"
	mainmenu_btn.add_theme_font_size_override("font_size", 18)
	mainmenu_btn.custom_minimum_size = Vector2(0, 40)
	mainmenu_btn.disabled = true
	inner.add_child(mainmenu_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Neu laden"
	restart_btn.add_theme_font_size_override("font_size", 18)
	restart_btn.custom_minimum_size = Vector2(0, 40)
	restart_btn.disabled = true
	inner.add_child(restart_btn)

	inner.add_child(HSeparator.new())

	# Hinweis
	var esc_hint := Label.new()
	esc_hint.text = "ESC oder Start zum Fortsetzen"
	esc_hint.add_theme_font_size_override("font_size", 14)
	esc_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(esc_hint)

	resume_btn.grab_focus()

func _resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	if pause_layer:
		pause_layer.queue_free()
		pause_layer = null
	get_tree().paused = false
# ── Death ────────────────────────────────────────────────────────────────────

func _on_player_died() -> void:
	in_shop = true
	game_over = true
	_pending_levels.clear()
	# Companion entfernen
	if companion and is_instance_valid(companion):
		companion.queue_free()
	# Bestehende Bomben entfernen
	for bomb in get_tree().get_nodes_in_group("bombs"):
		bomb.queue_free()
	# Musik stoppen
	_stop_wave_music()
	_show_game_over()


func _show_game_over() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Wave %d  |  Level %d  |  %d Gold" % [GameState.wave, GameState.player_level, GameState.gold]
	info.add_theme_font_size_override("font_size", 21)
	info.add_theme_color_override("font_color", Color.WHITE)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var btn := Button.new()
	btn.text = "Play Again"
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(180, 0)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(btn)

# ── HUD ──────────────────────────────────────────────────────────────────────

func _setup_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var bar := HBoxContainer.new()
	canvas.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.add_theme_constant_override("separation", 30)

	hud_health = _make_label("HP: 100/100")
	hud_wave   = _make_label("Wave 1")
	hud_gold   = _make_label("Gold: 0")
	hud_timer  = _make_label("⏱ 60")
	hud_level  = _make_label("Lv 1")
	hud_bomb   = _make_label("💣 0/3 [Q]")

	for lbl in [hud_health, hud_wave, hud_gold, hud_timer, hud_level, hud_bomb]:
		bar.add_child(lbl)

	# Steuerung-Hinweis unten rechts
	var hint := Label.new()
	hint.text = "Q: Bombe  |  ESC: Pause  |  Angriff: Auto"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -250
	hint.offset_top = -30
	canvas.add_child(hint)

	hud_xp_bar = ProgressBar.new()
	hud_xp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud_xp_bar.offset_top = -18
	hud_xp_bar.min_value = 0.0
	hud_xp_bar.max_value = 1.0
	hud_xp_bar.value = 0.0
	hud_xp_bar.show_percentage = false
	canvas.add_child(hud_xp_bar)

func _make_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

func _on_health_changed(current: int, maximum: int) -> void:
	hud_health.text = "HP: %d/%d" % [current, maximum]
	var pct := float(current) / float(maximum)
	var col := Color.RED if pct < 0.3 else (Color(1.0, 0.65, 0.0) if pct < 0.6 else Color.WHITE)
	hud_health.add_theme_color_override("font_color", col)

func _on_gold_changed(amount: int) -> void:
	hud_gold.text = "Gold: %d" % amount

func _on_xp_changed(current: int, next: int) -> void:
	hud_level.text = "Lv %d" % GameState.player_level
	hud_xp_bar.value = float(current) / float(next)

func _update_bomb_hud() -> void:
	hud_bomb.text = "💣 %d/%d [Q]" % [GameState.bomb_count, int(GameState.stats.max_bombs)]

# ── Bomben-Platzierung ─────────────────────────────────────────────────────────

func _place_bomb() -> void:
	if GameState.bomb_count >= int(GameState.stats.max_bombs):
		return
	if not player or not is_instance_valid(player):
		return

	var bomb = BOMB_SCENE.instantiate()
	bomb.global_position = player.global_position
	bomb.explosion_damage = int(GameState.stats.bomb_damage)
	bomb.explosion_radius = float(GameState.stats.bomb_radius)
	bomb.fuse_time = float(GameState.stats.bomb_fuse)
	add_child(bomb)

	GameState.bomb_count += 1
	_update_bomb_hud()
