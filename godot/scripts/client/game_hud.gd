extends CanvasLayer

signal combat_toggle_requested

@onready var hp_label: Label = $Panel/VBoxContainer/HPLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var combat_label: Label = $Panel/VBoxContainer/CombatLabel
@onready var loadout_label: Label = $Panel/VBoxContainer/LoadoutLabel
@onready var combat_toggle_button: Button = $Panel/VBoxContainer/CombatToggleButton


func _ready() -> void:
	combat_toggle_button.pressed.connect(_on_combat_toggle_button_pressed)
	update_health(100, 100)
	update_down_state(false)
	update_combat_mode(false)
	update_loadout("Slash, HP Regen")


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


func _on_combat_toggle_button_pressed() -> void:
	combat_toggle_requested.emit()
