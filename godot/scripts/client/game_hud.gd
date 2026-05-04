extends CanvasLayer

signal combat_toggle_requested
signal ability_toggle_requested(ability_name: String, enabled: bool)

@onready var hp_label: Label = $Panel/VBoxContainer/HPLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var combat_label: Label = $Panel/VBoxContainer/CombatLabel
@onready var loadout_label: Label = $Panel/VBoxContainer/LoadoutLabel
@onready var ability_list: VBoxContainer = $Panel/VBoxContainer/AbilityList
@onready var combat_toggle_button: Button = $Panel/VBoxContainer/CombatToggleButton

var _ability_enabled_by_name: Dictionary = {}
var _ability_state_by_name: Dictionary = {}
var _ability_display_name_by_name: Dictionary = {}
var _ability_check_box_by_name: Dictionary = {}
var _confirmed_loadout: Array[String] = []


func _ready() -> void:
	combat_toggle_button.pressed.connect(_on_combat_toggle_button_pressed)
	update_health(100, 100)
	update_down_state(false)
	update_combat_mode(false)
	update_loadout([])


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


func update_loadout(loadout_entries: Array) -> void:
	_confirmed_loadout.clear()
	_ability_display_name_by_name.clear()
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var ability_name: String = str(entry.get("ability_name", "")).strip_edges()
		if ability_name == "":
			continue

		var display_name: String = str(entry.get("display_name", ability_name)).strip_edges()
		_confirmed_loadout.append(ability_name)
		_ability_display_name_by_name[ability_name] = display_name if display_name != "" else ability_name
		if not _ability_enabled_by_name.has(ability_name):
			_ability_enabled_by_name[ability_name] = true

	var known_abilities: Array = _ability_state_by_name.keys()
	for ability_name in known_abilities:
		if not _confirmed_loadout.has(str(ability_name)):
			_ability_state_by_name.erase(ability_name)
			_ability_enabled_by_name.erase(ability_name)

	_rebuild_ability_controls()
	_update_loadout_label()


func update_ability_enabled(ability_name: String, enabled: bool) -> void:
	if not _confirmed_loadout.has(ability_name):
		return

	_ability_enabled_by_name[ability_name] = enabled
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	state["enabled"] = enabled
	_ability_state_by_name[ability_name] = state
	_update_ability_display(ability_name)


func update_ability_state(ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:
	if not _confirmed_loadout.has(ability_name):
		return

	_ability_enabled_by_name[ability_name] = enabled
	var state: Dictionary = {
		"enabled": enabled,
		"active": active,
		"cooldown_remaining": cooldown_remaining,
	}
	_ability_state_by_name[ability_name] = state
	_update_ability_display(ability_name)


func _rebuild_ability_controls() -> void:
	for child in ability_list.get_children():
		ability_list.remove_child(child)
		child.queue_free()
	_ability_check_box_by_name.clear()

	for ability_name in _confirmed_loadout:
		var check_box: CheckBox = CheckBox.new()
		check_box.focus_mode = Control.FOCUS_NONE
		check_box.toggled.connect(_on_ability_check_box_toggled.bind(ability_name))
		ability_list.add_child(check_box)
		_ability_check_box_by_name[ability_name] = check_box
		_update_ability_display(ability_name)


func _update_loadout_label() -> void:
	if _confirmed_loadout.is_empty():
		loadout_label.text = "Loadout: waiting for server"
		return

	var display_names: PackedStringArray = PackedStringArray()
	for ability_name in _confirmed_loadout:
		display_names.append(str(_ability_display_name_by_name.get(ability_name, ability_name)))
	loadout_label.text = "Loadout: %s" % ", ".join(display_names)


func _update_ability_display(ability_name: String) -> void:
	if not _ability_check_box_by_name.has(ability_name):
		return

	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	var enabled: bool = bool(state.get("enabled", _ability_enabled_by_name.get(ability_name, true)))
	var active: bool = bool(state.get("active", false))
	var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
	var enabled_text: String = "ON" if enabled else "OFF"
	var active_text: String = "active" if active else "inactive"
	var cooldown_text: String = ""
	if cooldown_remaining > 0.05:
		cooldown_text = " | CD %.1fs" % cooldown_remaining

	var display_name: String = str(_ability_display_name_by_name.get(ability_name, ability_name))
	var check_box: CheckBox = _ability_check_box_by_name[ability_name] as CheckBox
	check_box.set_pressed_no_signal(enabled)
	check_box.text = "%s: %s | %s%s" % [display_name, enabled_text, active_text, cooldown_text]


func _on_combat_toggle_button_pressed() -> void:
	combat_toggle_requested.emit()


func _on_ability_check_box_toggled(enabled: bool, ability_name: String) -> void:
	if not _confirmed_loadout.has(ability_name):
		return

	ability_toggle_requested.emit(ability_name, enabled)
	if not _ability_check_box_by_name.has(ability_name):
		return

	var check_box: CheckBox = _ability_check_box_by_name[ability_name] as CheckBox
	check_box.set_pressed_no_signal(bool(_ability_enabled_by_name.get(ability_name, true)))
