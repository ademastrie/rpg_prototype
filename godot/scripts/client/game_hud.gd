extends CanvasLayer

signal combat_toggle_requested
signal ability_toggle_requested(ability_name: String, enabled: bool)

@onready var hp_label: Label = $Panel/VBoxContainer/HPLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var combat_label: Label = $Panel/VBoxContainer/CombatLabel
@onready var loadout_label: Label = $Panel/VBoxContainer/LoadoutLabel
@onready var slash_check_box: CheckBox = $Panel/VBoxContainer/SlashCheckBox
@onready var hp_regen_check_box: CheckBox = $Panel/VBoxContainer/HPRegenCheckBox
@onready var damage_aura_check_box: CheckBox = $Panel/VBoxContainer/DamageAuraCheckBox
@onready var firebolt_check_box: CheckBox = $Panel/VBoxContainer/FireboltCheckBox
@onready var combat_toggle_button: Button = $Panel/VBoxContainer/CombatToggleButton

var _ability_enabled_by_name: Dictionary = {
	"Slash": true,
	"HP Regen": true,
	"Damage Aura": true,
	"Firebolt": true,
}
var _ability_state_by_name: Dictionary = {}


func _ready() -> void:
	combat_toggle_button.pressed.connect(_on_combat_toggle_button_pressed)
	slash_check_box.toggled.connect(_on_slash_check_box_toggled)
	hp_regen_check_box.toggled.connect(_on_hp_regen_check_box_toggled)
	damage_aura_check_box.toggled.connect(_on_damage_aura_check_box_toggled)
	firebolt_check_box.toggled.connect(_on_firebolt_check_box_toggled)
	update_health(100, 100)
	update_down_state(false)
	update_combat_mode(false)
	update_loadout("Slash, HP Regen, Damage Aura, Firebolt")
	update_ability_enabled("Slash", true)
	update_ability_enabled("HP Regen", true)
	update_ability_enabled("Damage Aura", true)
	update_ability_enabled("Firebolt", true)


func _process(delta: float) -> void:
	var ability_names: Array = _ability_state_by_name.keys()
	for ability_name in ability_names:
		var state: Dictionary = _ability_state_by_name[ability_name] as Dictionary
		var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
		if cooldown_remaining > 0.0:
			state["cooldown_remaining"] = max(cooldown_remaining - delta, 0.0)
			_ability_state_by_name[ability_name] = state
			_update_ability_display(str(ability_name))


func update_health(current_hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %s/%s" % [current_hp, max_hp]


func update_down_state(is_down: bool) -> void:
	if is_down:
		status_label.text = "Status: DOWN"
	else:
		status_label.text = "Status: Alive"


func update_combat_mode(combat_enabled: bool) -> void:
	if combat_enabled:
		combat_label.text = "Combat: ON"
	else:
		combat_label.text = "Combat: OFF"


func update_loadout(loadout_text: String) -> void:
	loadout_label.text = "Loadout: %s" % loadout_text


func update_ability_enabled(ability_name: String, enabled: bool) -> void:
	_ability_enabled_by_name[ability_name] = enabled
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	state["enabled"] = enabled
	_ability_state_by_name[ability_name] = state
	_update_ability_display(ability_name)


func update_ability_state(ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:
	_ability_enabled_by_name[ability_name] = enabled
	var state: Dictionary = {
		"enabled": enabled,
		"active": active,
		"cooldown_remaining": cooldown_remaining,
	}
	_ability_state_by_name[ability_name] = state
	_update_ability_display(ability_name)


func _update_ability_display(ability_name: String) -> void:
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	var enabled: bool = bool(state.get("enabled", _ability_enabled_by_name.get(ability_name, true)))
	var active: bool = bool(state.get("active", false))
	var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
	var enabled_text: String = "ON" if enabled else "OFF"
	var active_text: String = "active" if active else "inactive"
	var cooldown_text: String = ""
	if cooldown_remaining > 0.05:
		cooldown_text = " | CD %.1fs" % cooldown_remaining

	var display_text: String = "%s: %s | %s%s" % [ability_name, enabled_text, active_text, cooldown_text]
	if ability_name == "Slash":
		slash_check_box.set_pressed_no_signal(enabled)
		slash_check_box.text = display_text
	elif ability_name == "HP Regen":
		hp_regen_check_box.set_pressed_no_signal(enabled)
		hp_regen_check_box.text = display_text
	elif ability_name == "Damage Aura":
		damage_aura_check_box.set_pressed_no_signal(enabled)
		damage_aura_check_box.text = display_text
	elif ability_name == "Firebolt":
		firebolt_check_box.set_pressed_no_signal(enabled)
		firebolt_check_box.text = display_text


func _on_combat_toggle_button_pressed() -> void:
	combat_toggle_requested.emit()


func _on_slash_check_box_toggled(enabled: bool) -> void:
	ability_toggle_requested.emit("Slash", enabled)
	slash_check_box.set_pressed_no_signal(bool(_ability_enabled_by_name.get("Slash", true)))


func _on_hp_regen_check_box_toggled(enabled: bool) -> void:
	ability_toggle_requested.emit("HP Regen", enabled)
	hp_regen_check_box.set_pressed_no_signal(bool(_ability_enabled_by_name.get("HP Regen", true)))


func _on_damage_aura_check_box_toggled(enabled: bool) -> void:
	ability_toggle_requested.emit("Damage Aura", enabled)
	damage_aura_check_box.set_pressed_no_signal(bool(_ability_enabled_by_name.get("Damage Aura", true)))


func _on_firebolt_check_box_toggled(enabled: bool) -> void:
	ability_toggle_requested.emit("Firebolt", enabled)
	firebolt_check_box.set_pressed_no_signal(bool(_ability_enabled_by_name.get("Firebolt", true)))
