extends CanvasLayer

signal combat_toggle_requested
signal ability_toggle_requested(ability_name: String, enabled: bool)
signal loadout_save_requested(loadout_entries: Array)

@onready var hud_vbox: VBoxContainer = $Panel/VBoxContainer
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
var _confirmed_loadout_entries: Array = []
var _unlocked_abilities: Array = []
var _ability_panel: PanelContainer = null
var _ability_panel_button: Button = null
var _ability_slot_rows: Array = []
var _ability_panel_status: Label = null


func _ready() -> void:
	combat_toggle_button.pressed.connect(_on_combat_toggle_button_pressed)
	_build_ability_panel()
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
	_confirmed_loadout_entries.clear()
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
		_confirmed_loadout_entries.append(entry.duplicate())
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
	_refresh_ability_panel_rows()


func update_unlocked_abilities(unlocked_abilities: Array) -> void:
	_unlocked_abilities = unlocked_abilities.duplicate()
	_refresh_ability_panel_options()
	_refresh_ability_panel_rows()


func toggle_ability_panel() -> void:
	if _ability_panel == null:
		return

	_ability_panel.visible = not _ability_panel.visible


func update_ability_enabled(ability_name: String, enabled: bool) -> void:
	if not _confirmed_loadout.has(ability_name):
		return

	_ability_enabled_by_name[ability_name] = enabled
	_update_confirmed_loadout_entry_enabled(ability_name, enabled)
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	state["enabled"] = enabled
	_ability_state_by_name[ability_name] = state
	_update_ability_display(ability_name)
	_refresh_ability_panel_rows()


func update_ability_state(ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:
	if not _confirmed_loadout.has(ability_name):
		return

	_ability_enabled_by_name[ability_name] = enabled
	_update_confirmed_loadout_entry_enabled(ability_name, enabled)
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


func _build_ability_panel() -> void:
	_ability_panel_button = Button.new()
	_ability_panel_button.text = "Abilities"
	_ability_panel_button.pressed.connect(toggle_ability_panel)
	hud_vbox.add_child(_ability_panel_button)

	_ability_panel = PanelContainer.new()
	_ability_panel.visible = false
	hud_vbox.add_child(_ability_panel)

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	_ability_panel.add_child(panel_vbox)

	var title_label: Label = Label.new()
	title_label.text = "Ability Loadout"
	panel_vbox.add_child(title_label)

	for slot_index in range(5):
		var row: HBoxContainer = HBoxContainer.new()
		panel_vbox.add_child(row)

		var slot_label: Label = Label.new()
		slot_label.text = "Slot %s" % [slot_index + 1]
		row.add_child(slot_label)

		var option: OptionButton = OptionButton.new()
		option.custom_minimum_size = Vector2(160.0, 0.0)
		row.add_child(option)

		var enabled_check_box: CheckBox = CheckBox.new()
		enabled_check_box.text = "Enabled"
		row.add_child(enabled_check_box)

		_ability_slot_rows.append({
			"option": option,
			"enabled": enabled_check_box,
		})

	var save_button: Button = Button.new()
	save_button.text = "Save Loadout"
	save_button.pressed.connect(_on_save_loadout_pressed)
	panel_vbox.add_child(save_button)

	_ability_panel_status = Label.new()
	_ability_panel_status.text = ""
	panel_vbox.add_child(_ability_panel_status)

	_refresh_ability_panel_options()


func _refresh_ability_panel_options() -> void:
	for row_variant in _ability_slot_rows:
		var row: Dictionary = row_variant as Dictionary
		var option: OptionButton = row["option"] as OptionButton
		option.clear()
		option.add_item("Empty")
		option.set_item_metadata(0, "")
		for ability_variant in _unlocked_abilities:
			if not (ability_variant is Dictionary):
				continue

			var ability: Dictionary = ability_variant as Dictionary
			var ability_key: String = str(ability.get("ability_key", "")).strip_edges()
			if ability_key == "":
				continue

			var display_name: String = str(ability.get("display_name", ability_key)).strip_edges()
			option.add_item(display_name if display_name != "" else ability_key)
			option.set_item_metadata(option.get_item_count() - 1, ability_key)


func _refresh_ability_panel_rows() -> void:
	if _ability_slot_rows.is_empty():
		return

	for slot_index in range(_ability_slot_rows.size()):
		var row: Dictionary = _ability_slot_rows[slot_index] as Dictionary
		var option: OptionButton = row["option"] as OptionButton
		var enabled_check_box: CheckBox = row["enabled"] as CheckBox
		var entry: Dictionary = {}
		for entry_variant in _confirmed_loadout_entries:
			var loadout_entry: Dictionary = entry_variant as Dictionary
			if int(loadout_entry.get("slot_index", 0)) == slot_index:
				entry = loadout_entry
				break

		var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
		_select_ability_option(option, ability_key)
		enabled_check_box.button_pressed = bool(entry.get("enabled", true))

	if _ability_panel_status != null:
		_ability_panel_status.text = ""


func _select_ability_option(option: OptionButton, ability_key: String) -> void:
	for item_index in range(option.get_item_count()):
		if str(option.get_item_metadata(item_index)) == ability_key:
			option.select(item_index)
			return

	option.select(0)


func _update_confirmed_loadout_entry_enabled(ability_name: String, enabled: bool) -> void:
	for entry_index in range(_confirmed_loadout_entries.size()):
		var entry: Dictionary = _confirmed_loadout_entries[entry_index] as Dictionary
		if str(entry.get("ability_name", "")) == ability_name:
			entry["enabled"] = enabled
			_confirmed_loadout_entries[entry_index] = entry
			return


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


func _on_save_loadout_pressed() -> void:
	var loadout_entries: Array = []
	var seen_keys: Array[String] = []
	for slot_index in range(_ability_slot_rows.size()):
		var row: Dictionary = _ability_slot_rows[slot_index] as Dictionary
		var option: OptionButton = row["option"] as OptionButton
		var enabled_check_box: CheckBox = row["enabled"] as CheckBox
		var selected_index: int = option.selected
		if selected_index < 0:
			continue

		var ability_key: String = str(option.get_item_metadata(selected_index)).strip_edges()
		if ability_key == "":
			continue
		if seen_keys.has(ability_key):
			_ability_panel_status.text = "Duplicate abilities are not allowed."
			return

		seen_keys.append(ability_key)
		loadout_entries.append({
			"slot_index": slot_index,
			"ability_key": ability_key,
			"enabled": enabled_check_box.button_pressed,
		})

	if loadout_entries.size() > 5:
		_ability_panel_status.text = "Loadout can contain at most 5 abilities."
		return
	if loadout_entries.is_empty():
		_ability_panel_status.text = "Choose at least one ability."
		return

	_ability_panel_status.text = "Saving..."
	loadout_save_requested.emit(loadout_entries)
