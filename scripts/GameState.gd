extends Node

const XpCurve = preload("res://scripts/logic/XpCurve.gd")
const ShopRules = preload("res://scripts/logic/ShopRules.gd")
const LevelUpRules = preload("res://scripts/logic/LevelUpRules.gd")

signal health_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal xp_changed(current: int, next_level: int)
signal leveled_up(new_level: int)

var wave: int = 1
var gold: int = 0
var xp: int = 0
var xp_to_next: int = 10
var player_level: int = 1
var bomb_count: int = 0

# ── Stats-System (erweiterbar für Items/Buffs) ─────────────────────────────────
# Spieler-Stats (Upgrades wirken hier rein)
var stats: Dictionary = make_base_stats()
# Companion-Stats (eigener, getrennter Satz – kann später eigene Upgrades bekommen)
var companion_stats: Dictionary = make_base_stats()

# ── Basis-Stats ────────────────────────────────────────────────────────────────
# Eine zentrale Vorlage für Player UND Companion, damit neue Stats an EINER
# Stelle ergänzt werden (Items/Buffs in Zukunft greifen einfach hier zu).
func make_base_stats() -> Dictionary:
	return {
		# ── Basis ─────────────────────────────────────────────────────────────
		"max_health": 100,        # Max. Leben
		"speed": 400.0,           # Laufgeschwindigkeit
		"damage": 50,             # Grundschaden
		"damage_mult": 1.0,       # Schaden % (1.0 = 100%, 1.5 = +50%)
		"attack_speed": 1.0,      # Angriffstempo (Multiplikator)
		"range": 150.0,           # Reichweite Waffe
		"fire_rate": 3.5,         # Schussrate (Projektilen/Sekunde)
		"bullet_speed": 3000.0,   # Geschossgeschwindigkeit
		# ── Verteidigung ───────────────────────────────────────────────────────
		"armor": 0,               # Rüstung (flacher Schaden-Abzug)
		"armor_mult": 1.0,        # Rüstung % (vervielfacht die Rüstung)
		"dodge_chance": 0.0,      # Ausweichen % (Chance, Treffer komplett zu vermeiden)
		# ── Element / Effekt ───────────────────────────────────────────────────
		"ice_damage": 0.0,        # Zusätzlicher Eisschaden pro Treffer
		"freeze_duration": 0.0,   # Wie lange ein Treffer den Gegner einfriert (Sek.)
		# ── Überleben ──────────────────────────────────────────────────────────
		"lifesteal": 0.0,         # Lebensabzug % (Vampir: Heilung pro Schaden, 0.1 = 10%)
		"hp_regen": 0.0,          # Lebensregeneration pro Sekunde
		# ── Zusätzliche (für die Zukunft) ──────────────────────────────────────
		"crit_chance": 0.0,       # Krit-Treffer-Chance %
		"crit_damage": 1.5,       # Krit-Schaden-Multiplikator
		"projectile_count": 1,    # Anzahl parallel abgeschossener Projektile
		"pierce": 0,              # Wie viele Gegner ein Projektil durchdringt
		# ── Ressourcen / Bomben ────────────────────────────────────────────────
		"xp_mult": 1.0,
		"gold_mult": 1.0,
		"bomb_damage": 80,
		"bomb_radius": 500.0,
		"bomb_fuse": 10.0,
		"max_bombs": 10,
	}

# ── Upgrade-Pool (Items/Buffs) ─────────────────────────────────────────────────
# Jedes Upgrade greift über "stat" in das Stats-Dictionary zu (apply_upgrade).
# Neue Items werden hier einfach ergänzt.
const UPGRADES = [
	# Leben / Überleben
	{"label": "+25 Max HP",       "stat": "max_health",   "value": 25,    "cost": 8},
	{"label": "+0.5 HP/S Regen",  "stat": "hp_regen",     "value": 0.5,   "cost": 12},
	{"label": "+10% Vampirismus", "stat": "lifesteal",    "value": 0.10,  "cost": 15},
	{"label": "+5% Ausweichen",   "stat": "dodge_chance", "value": 0.05,  "cost": 10},
	# Schaden / Angriff
	{"label": "+5 Schaden",       "stat": "damage",       "value": 5,     "cost": 10},
	{"label": "+15% Schaden",     "stat": "damage_mult",  "value": 0.15,  "cost": 14},
	{"label": "+10% Angriffstempo","stat": "attack_speed","value": 0.10,  "cost": 11},
	{"label": "+40 Reichweite",   "stat": "range",        "value": 40.0,  "cost": 9},
	{"label": "+0.3 Schussrate",  "stat": "fire_rate",    "value": 0.3,   "cost": 12},
	{"label": "+80 Geschossspeed","stat": "bullet_speed", "value": 80.0,  "cost": 7},
	{"label": "+1 Projektile",    "stat": "projectile_count", "value": 1, "cost": 18},
	{"label": "+1 Durchschlag",   "stat": "pierce",       "value": 1,     "cost": 16},
	{"label": "+10% Krit-Chance", "stat": "crit_chance",  "value": 0.10,  "cost": 13},
	{"label": "+0.5x Krit-Schaden","stat": "crit_damage", "value": 0.5,   "cost": 13},
	# Verteidigung
	{"label": "+2 Rüstung",       "stat": "armor",        "value": 2,     "cost": 8},
	{"label": "+20% Rüstung",     "stat": "armor_mult",   "value": 0.20,  "cost": 14},
	# Eis / Element
	{"label": "+5 Eisschaden",    "stat": "ice_damage",   "value": 5,     "cost": 15},
	{"label": "+0.5s Freeze",     "stat": "freeze_duration","value": 0.5, "cost": 16},
	# Fortbewegung / Ressourcen
	{"label": "+30 Speed",        "stat": "speed",        "value": 30.0,  "cost": 6},
	{"label": "+20% XP",          "stat": "xp_mult",      "value": 0.20,  "cost": 5},
	{"label": "+20% Gold",        "stat": "gold_mult",    "value": 0.20,  "cost": 5},
]

func apply_upgrade(upgrade: Dictionary) -> void:
	ShopRules.apply_upgrade(stats, upgrade)

func add_xp(amount: int) -> void:
	var result := XpCurve.apply_xp(xp, xp_to_next, player_level, XpCurve.scaled_xp(amount, stats.xp_mult))
	xp = result.xp
	xp_to_next = result.xp_to_next
	var old_level := player_level
	player_level = result.level
	emit_signal("xp_changed", xp, xp_to_next)
	for level in LevelUpRules.levels_reached(old_level, player_level):
		leveled_up.emit(level)

func add_gold(amount: int) -> void:
	gold += XpCurve.scaled_gold(amount, stats.gold_mult)
	emit_signal("gold_changed", gold)

func reset() -> void:
	wave = 1
	gold = 0
	xp = 0
	xp_to_next = 10
	player_level = 1
	stats = make_base_stats()
	companion_stats = make_base_stats()
