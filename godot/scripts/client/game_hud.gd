extends CanvasLayer

signal combat_toggle_requested
signal ability_toggle_requested(ability_name: String, enabled: bool)
signal weapon_primary_requested
signal loadout_save_requested(loadout_entries: Array)
signal equipment_change_requested(equipment_entries: Array)

const HOTBAR_SLOT_COUNT: int = 5
const PANEL_BACKGROUND_COLOR: Color = Color(0.05, 0.06, 0.07, 0.92)
const PANEL_BORDER_COLOR: Color = Color(0.35, 0.38, 0.42, 0.95)
const PANEL_TEXT_COLOR: Color = Color(0.93, 0.94, 0.95, 1.0)
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "head", "chest", "arms", "hands", "legs", "feet"]
const EQUIPMENT_SLOT_LABELS: Dictionary = {
	"weapon": "Weapon",
	"head": "Head",
	"chest": "Chest",
	"arms": "Arms",
	"hands": "Hands",
	"legs": "Legs",
	"feet": "Feet",
}
const ITEM_STAT_LABELS: Dictionary = {
	"max_hp": "Max HP",
	"move_speed": "Move Speed",
	"physical_power": "Physical Power",
	"spell_power": "Spell Power",
	"armor": "Armor",
	"avoidance": "Avoidance",
}
const ITEM_STAT_ALIASES: Dictionary = {
	"attack_power": "physical_power",
	"damage_reduction": "armor",
}
const ITEM_STAT_DISPLAY_ORDER: Array[String] = ["max_hp", "move_speed", "physical_power", "spell_power", "armor", "avoidance"]

var _root: Control = null
var _hud_panel: PanelContainer = null
var _hud_vbox: VBoxContainer = null
var _hp_label: Label = null
var _progression_label: Label = null
var _gold_label: Label = null
var _combat_label: Label = null
var _status_label: Label = null
var _message_label: Label = null
var _combat_toggle_button: Button = null
var _character_panel_button: Button = null
var _ability_panel_button: Button = null
var _inventory_panel_button: Button = null
var _weapon_primary_button: Button = null
var _hotbar: HBoxContainer = null
var _character_panel: PanelContainer = null
var _ability_panel: PanelContainer = null
var _inventory_panel: PanelContainer = null
var _ability_list: VBoxContainer = null
var _inventory_list: VBoxContainer = null
var _inventory_comparison_label: Label = null
var _ability_panel_status: Label = null
var _character_level_label: Label = null
var _character_xp_label: Label = null
var _character_gold_label: Label = null
var _character_max_hp_label: Label = null
var _character_physical_power_label: Label = null
var _character_spell_power_label: Label = null
var _character_armor_label: Label = null
var _character_avoidance_label: Label = null
var _character_move_speed_label: Label = null
var _equipment_slot_labels: Dictionary = {}
var _equipment_slot_options: Dictionary = {}
var _equipment_panel_status: Label = null

var _message_timer: SceneTreeTimer = null
var _ability_enabled_by_name: Dictionary = {}
var _ability_state_by_name: Dictionary = {}
var _ability_display_name_by_name: Dictionary = {}
var _ability_check_box_by_name: Dictionary = {}
var _hotbar_button_by_slot: Dictionary = {}
var _weapon_primary_ability: Dictionary = {}
var _confirmed_loadout: Array[String] = []
var _confirmed_loadout_entries: Array = []
var _unlocked_abilities: Array = []
var _ability_slot_rows: Array = []
var _draft_loadout_entries: Array = []
var _pending_loadout_entries: Array = []
var _is_loadout_draft_active: bool = false
var _is_loadout_draft_dirty: bool = false
var _is_loadout_save_pending: bool = false
var _current_level: int = 1
var _current_xp: int = 0
var _current_xp_to_next: int = 0
var _current_gold: int = 0
var _confirmed_inventory_items: Array = []
var _confirmed_equipment: Dictionary = {}
var _selected_inventory_item: Dictionary = {}
var _is_equipment_change_pending: bool = false
var _is_refreshing_equipment_ui: bool = false
var _current_max_hp: int = 100
var _current_physical_power: float = 0.0
var _current_spell_power: float = 0.0
var _current_armor: float = 0.0
var _current_avoidance: float = 0.0
var _current_move_speed: float = 0.0
var _has_confirmed_combat_stats: bool = false
var _dragged_panel: Control = null
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_layout()
	update_health(100, 100)
	update_progression(1, 0, 100)
	update_gold(0)
	update_down_state(false)
	update_combat_mode(false)
	update_combat_stats({})
	update_weapon_primary_ability({})
	update_loadout([])


func _process(delta: float) -> void:
	if _dragged_panel != null:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_move_dragged_panel()
		else:
			_dragged_panel = null

	var ability_names: Array = _ability_state_by_name.keys()
	for ability_name in ability_names:
		var state: Dictionary = _ability_state_by_name[ability_name] as Dictionary
		var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
		if cooldown_remaining > 0.0:
			state["cooldown_remaining"] = max(cooldown_remaining - delta, 0.0)
			_ability_state_by_name[ability_name] = state
			_update_ability_display(str(ability_name))


func update_health(current_hp: int, max_hp: int) -> void:
	_hp_label.text = "HP: %s/%s" % [current_hp, max_hp]
	_current_max_hp = max(max_hp, 1)
	_refresh_character_panel()


func update_progression(level: int, xp: int, xp_to_next: int, xp_awarded: int = 0, leveled_up: bool = false, _levels_gained: int = 0) -> void:
	_current_level = max(level, 1)
	_current_xp = max(xp, 0)
	_current_xp_to_next = max(xp_to_next, 0)
	var xp_to_next_text: String = str(_current_xp_to_next) if _current_xp_to_next > 0 else "--"
	var progression_text: String = "Level: %s | XP: %s/%s" % [_current_level, _current_xp, xp_to_next_text]
	if xp_awarded > 0:
		progression_text = "%s | +%s XP" % [progression_text, xp_awarded]
	if leveled_up:
		progression_text = "%s | Level Up! %s" % [progression_text, _current_level]
	_progression_label.text = progression_text
	_refresh_character_panel()


func update_gold(gold: int) -> void:
	_current_gold = max(gold, 0)
	_gold_label.text = "Gold: %s" % _current_gold
	_refresh_character_panel()


func update_inventory_items(inventory_items: Array) -> void:
	_confirmed_inventory_items = inventory_items.duplicate(true)
	_refresh_selected_inventory_item()
	_refresh_inventory_panel()
	_refresh_equipment_slot_options()
	_refresh_inventory_comparison()


func update_equipment(equipment: Dictionary) -> void:
	_confirmed_equipment = equipment.duplicate(true)
	_is_equipment_change_pending = false
	if _equipment_panel_status != null:
		_equipment_panel_status.text = "Saved."
	_refresh_character_panel()
	_refresh_inventory_panel()
	_refresh_equipment_slot_options()
	_refresh_inventory_comparison()


func update_down_state(is_down: bool) -> void:
	_status_label.text = "Status: DOWN" if is_down else "Status: Alive"


func update_combat_mode(combat_enabled: bool) -> void:
	_combat_label.text = "Combat: ON" if combat_enabled else "Combat: OFF"


func update_combat_stats(combat_stats: Dictionary) -> void:
	if combat_stats.is_empty():
		_has_confirmed_combat_stats = false
		_refresh_character_panel()
		return

	_has_confirmed_combat_stats = true
	_current_max_hp = int(combat_stats.get("max_hp", _current_max_hp))
	_current_physical_power = float(combat_stats.get("physical_power", combat_stats.get("attack_power", _current_physical_power)))
	_current_spell_power = float(combat_stats.get("spell_power", _current_spell_power))
	_current_armor = float(combat_stats.get("armor", combat_stats.get("damage_reduction", _current_armor)))
	_current_avoidance = float(combat_stats.get("avoidance", _current_avoidance))
	_current_move_speed = float(combat_stats.get("move_speed", _current_move_speed))
	_refresh_character_panel()


func update_loadout(loadout_entries: Array) -> void:
	_confirmed_loadout.clear()
	_confirmed_loadout_entries.clear()
	_ability_display_name_by_name.clear()
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var raw_entry: Dictionary = entry_variant as Dictionary
		var entry: Dictionary = raw_entry.duplicate()
		var ability_name: String = str(entry.get("ability_name", "")).strip_edges()
		if ability_name == "":
			continue

		var display_name: String = str(entry.get("display_name", ability_name)).strip_edges()
		_confirmed_loadout.append(ability_name)
		_confirmed_loadout_entries.append(entry)
		_ability_display_name_by_name[ability_name] = display_name if display_name != "" else ability_name
		_ability_enabled_by_name[ability_name] = bool(entry.get("enabled", _ability_enabled_by_name.get(ability_name, true)))

	var known_abilities: Array = _ability_state_by_name.keys()
	for ability_name in known_abilities:
		if not _confirmed_loadout.has(str(ability_name)):
			_ability_state_by_name.erase(ability_name)
			_ability_enabled_by_name.erase(ability_name)

	_rebuild_ability_controls()
	_refresh_hotbar()
	if _is_loadout_save_pending and _loadout_entries_match(_confirmed_loadout_entries, _pending_loadout_entries):
		_is_loadout_save_pending = false
		_pending_loadout_entries.clear()
		if _loadout_entries_match(_confirmed_loadout_entries, _draft_loadout_entries):
			_is_loadout_draft_dirty = false
			_initialize_loadout_draft_from_confirmed()
			if _ability_panel_status != null:
				_ability_panel_status.text = "Saved."
	elif _is_loadout_draft_active and not _is_loadout_draft_dirty:
		_initialize_loadout_draft_from_confirmed()

	_refresh_ability_panel_options()
	_refresh_ability_panel_rows()


func update_weapon_primary_ability(weapon_primary_ability: Dictionary) -> void:
	var previous_ability_name: String = _weapon_primary_ability_name()
	_weapon_primary_ability = weapon_primary_ability.duplicate(true)
	if previous_ability_name != "" and previous_ability_name != _weapon_primary_ability_name() and not _confirmed_loadout.has(previous_ability_name):
		_ability_state_by_name.erase(previous_ability_name)
		_ability_enabled_by_name.erase(previous_ability_name)
	var ability_name: String = str(_weapon_primary_ability.get("ability_name", "")).strip_edges()
	if ability_name != "":
		var display_name: String = str(_weapon_primary_ability.get("display_name", ability_name)).strip_edges()
		_ability_display_name_by_name[ability_name] = display_name if display_name != "" else ability_name

	_refresh_weapon_primary_button()


func update_unlocked_abilities(unlocked_abilities: Array) -> void:
	_unlocked_abilities = unlocked_abilities.duplicate()
	_refresh_ability_panel_options()
	if not _is_loadout_draft_active or not _is_loadout_draft_dirty:
		_refresh_ability_panel_rows()


func show_status_message(message: String) -> void:
	_message_label.text = message
	_message_label.visible = message.strip_edges() != ""
	if _message_label.visible:
		_message_timer = get_tree().create_timer(4.0)
		_message_timer.timeout.connect(_on_message_timer_timeout.bind(_message_timer))


func toggle_character_panel() -> void:
	_character_panel.visible = not _character_panel.visible


func toggle_ability_panel() -> void:
	if _ability_panel.visible:
		_cancel_loadout_draft()
		_ability_panel.visible = false
		return

	_begin_loadout_draft()
	_ability_panel.visible = true


func toggle_inventory_panel() -> void:
	_inventory_panel.visible = not _inventory_panel.visible


func update_ability_enabled(ability_name: String, enabled: bool) -> void:
	if not _confirmed_loadout.has(ability_name):
		return

	_ability_enabled_by_name[ability_name] = enabled
	_update_confirmed_loadout_entry_enabled(ability_name, enabled)
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	state["enabled"] = enabled
	_ability_state_by_name[ability_name] = state
	_update_ability_display(ability_name)
	if _is_loadout_draft_active and not _is_loadout_draft_dirty:
		_initialize_loadout_draft_from_confirmed()
	_refresh_ability_panel_rows()


func update_ability_state(ability_name: String, enabled: bool, active: bool, cooldown_remaining: float) -> void:
	if not _confirmed_loadout.has(ability_name) and ability_name != _weapon_primary_ability_name():
		return

	_ability_enabled_by_name[ability_name] = enabled
	_update_confirmed_loadout_entry_enabled(ability_name, enabled)
	_ability_state_by_name[ability_name] = {
		"enabled": enabled,
		"active": active,
		"cooldown_remaining": cooldown_remaining,
	}
	_update_ability_display(ability_name)
	if ability_name == _weapon_primary_ability_name():
		_refresh_weapon_primary_button()
	if _is_loadout_draft_active and not _is_loadout_draft_dirty:
		_initialize_loadout_draft_from_confirmed()
	_refresh_ability_panel_rows()


func _build_layout() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_build_hud()
	_build_hotbar()
	_build_character_panel()
	_build_ability_panel()
	_build_inventory_panel()


func _build_hud() -> void:
	_hud_panel = PanelContainer.new()
	_hud_panel.name = "HUDPanel"
	_hud_panel.offset_left = 16.0
	_hud_panel.offset_top = 16.0
	_hud_panel.offset_right = 428.0
	_hud_panel.offset_bottom = 208.0
	_apply_panel_style(_hud_panel)
	_root.add_child(_hud_panel)

	_hud_vbox = VBoxContainer.new()
	_hud_vbox.name = "HUDVBox"
	_hud_vbox.add_theme_constant_override("separation", 4)
	_hud_panel.add_child(_hud_vbox)

	_hp_label = _add_label(_hud_vbox, "HP: 100/100")
	_progression_label = _add_label(_hud_vbox, "Level: 1 | XP: 0/100")
	_gold_label = _add_label(_hud_vbox, "Gold: 0")
	_combat_label = _add_label(_hud_vbox, "Combat: OFF")
	_status_label = _add_label(_hud_vbox, "Status: Alive")

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	_hud_vbox.add_child(button_row)

	_combat_toggle_button = _add_button(button_row, "Combat")
	_combat_toggle_button.pressed.connect(_on_combat_toggle_button_pressed)

	_character_panel_button = _add_button(button_row, "Character")
	_character_panel_button.pressed.connect(toggle_character_panel)

	_ability_panel_button = _add_button(button_row, "Abilities")
	_ability_panel_button.pressed.connect(toggle_ability_panel)

	_inventory_panel_button = _add_button(button_row, "Inventory")
	_inventory_panel_button.pressed.connect(toggle_inventory_panel)

	_message_label = _add_label(_hud_vbox, "")
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = false


func _build_hotbar() -> void:
	var hotbar_panel: PanelContainer = PanelContainer.new()
	hotbar_panel.name = "HotbarPanel"
	hotbar_panel.anchor_left = 0.5
	hotbar_panel.anchor_top = 1.0
	hotbar_panel.anchor_right = 0.5
	hotbar_panel.anchor_bottom = 1.0
	hotbar_panel.offset_left = -382.0
	hotbar_panel.offset_top = -108.0
	hotbar_panel.offset_right = 382.0
	hotbar_panel.offset_bottom = -16.0
	_apply_panel_style(hotbar_panel)
	_root.add_child(hotbar_panel)

	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.add_theme_constant_override("separation", 8)
	hotbar_panel.add_child(_hotbar)

	_weapon_primary_button = Button.new()
	_weapon_primary_button.focus_mode = Control.FOCUS_NONE
	_weapon_primary_button.custom_minimum_size = Vector2(128.0, 72.0)
	_weapon_primary_button.text = "Weapon\nNone"
	_weapon_primary_button.disabled = true
	_apply_button_text_colors(_weapon_primary_button)
	_weapon_primary_button.pressed.connect(_on_weapon_primary_button_pressed)
	_hotbar.add_child(_weapon_primary_button)

	for slot_index in range(HOTBAR_SLOT_COUNT):
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(112.0, 72.0)
		button.text = "%s\nEmpty" % [slot_index + 1]
		_apply_button_text_colors(button)
		button.pressed.connect(_on_hotbar_slot_pressed.bind(slot_index))
		_hotbar.add_child(button)
		_hotbar_button_by_slot[slot_index] = button


func _build_character_panel() -> void:
	_character_panel = PanelContainer.new()
	_character_panel.name = "CharacterPanel"
	_character_panel.visible = false
	_character_panel.anchor_left = 1.0
	_character_panel.anchor_right = 1.0
	_character_panel.offset_left = -696.0
	_character_panel.offset_top = 16.0
	_character_panel.offset_right = -16.0
	_character_panel.offset_bottom = 548.0
	_apply_panel_style(_character_panel)
	_root.add_child(_character_panel)

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 6)
	_character_panel.add_child(panel_vbox)

	var title_label: Label = _add_title_label(panel_vbox, "Character")
	title_label.gui_input.connect(_on_panel_drag_handle_input.bind(_character_panel))

	var main_row: HBoxContainer = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 10)
	panel_vbox.add_child(main_row)

	var equipment_panel: PanelContainer = PanelContainer.new()
	equipment_panel.custom_minimum_size = Vector2(420.0, 0.0)
	equipment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_section_panel_style(equipment_panel)
	main_row.add_child(equipment_panel)

	var equipment_vbox: VBoxContainer = VBoxContainer.new()
	equipment_vbox.add_theme_constant_override("separation", 6)
	equipment_panel.add_child(equipment_vbox)

	_add_label(equipment_vbox, "Equipment")
	_add_equipment_paper_doll_row(equipment_vbox, ["", "head", ""])
	_add_equipment_paper_doll_row(equipment_vbox, ["arms", "chest", "hands"])
	_add_equipment_paper_doll_row(equipment_vbox, ["", "legs", ""])
	_add_equipment_paper_doll_row(equipment_vbox, ["", "feet", ""])
	_add_equipment_paper_doll_row(equipment_vbox, ["", "weapon", ""])

	var stats_panel: PanelContainer = PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(224.0, 0.0)
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_section_panel_style(stats_panel)
	main_row.add_child(stats_panel)

	var stats_vbox: VBoxContainer = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_vbox)

	_add_label(stats_vbox, "Progress")
	_character_level_label = _add_label(stats_vbox, "")
	_character_xp_label = _add_label(stats_vbox, "")
	_character_gold_label = _add_label(stats_vbox, "")
	_add_label(stats_vbox, "Stats")
	_character_max_hp_label = _add_label(stats_vbox, "")
	_character_move_speed_label = _add_label(stats_vbox, "")
	_character_physical_power_label = _add_label(stats_vbox, "")
	_character_spell_power_label = _add_label(stats_vbox, "")
	_character_armor_label = _add_label(stats_vbox, "")
	_character_avoidance_label = _add_label(stats_vbox, "")

	_equipment_panel_status = _add_label(panel_vbox, "")
	_refresh_equipment_slot_options()
	_refresh_character_panel()


func _add_equipment_paper_doll_row(parent: Control, slot_names: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	for slot_name_variant in slot_names:
		var slot_name: String = str(slot_name_variant)
		if slot_name == "":
			_add_equipment_slot_spacer(row)
			continue

		_add_equipment_slot_card(row, slot_name)


func _add_equipment_slot_spacer(parent: Control) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(128.0, 76.0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)


func _add_equipment_slot_card(parent: Control, slot_name: String) -> void:
	var slot_panel: PanelContainer = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(128.0, 76.0)
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_slot_panel_style(slot_panel)
	parent.add_child(slot_panel)

	var slot_vbox: VBoxContainer = VBoxContainer.new()
	slot_vbox.add_theme_constant_override("separation", 2)
	slot_panel.add_child(slot_vbox)

	var slot_name_label: Label = _add_label(slot_vbox, str(EQUIPMENT_SLOT_LABELS.get(slot_name, slot_name.capitalize())))
	slot_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var item_label: Label = _add_label(slot_vbox, "Empty")
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_slot_labels[slot_name] = item_label

	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(116.0, 0.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_mode = Control.FOCUS_NONE
	_apply_button_text_colors(option)
	option.item_selected.connect(_on_equipment_option_selected.bind(slot_name))
	slot_vbox.add_child(option)
	_equipment_slot_options[slot_name] = option


func _build_ability_panel() -> void:
	_ability_panel = PanelContainer.new()
	_ability_panel.name = "AbilitiesPanel"
	_ability_panel.visible = false
	_ability_panel.anchor_left = 1.0
	_ability_panel.anchor_right = 1.0
	_ability_panel.offset_left = -432.0
	_ability_panel.offset_top = 216.0
	_ability_panel.offset_right = -16.0
	_ability_panel.offset_bottom = 548.0
	_apply_panel_style(_ability_panel)
	_root.add_child(_ability_panel)

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 6)
	_ability_panel.add_child(panel_vbox)

	var title_label: Label = _add_title_label(panel_vbox, "Abilities")
	title_label.gui_input.connect(_on_panel_drag_handle_input.bind(_ability_panel))
	_add_label(panel_vbox, "Current Loadout")

	_ability_list = VBoxContainer.new()
	_ability_list.add_theme_constant_override("separation", 2)
	panel_vbox.add_child(_ability_list)

	_add_label(panel_vbox, "Loadout Slots")
	for slot_index in range(HOTBAR_SLOT_COUNT):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		panel_vbox.add_child(row)

		var slot_label: Label = Label.new()
		slot_label.custom_minimum_size = Vector2(54.0, 0.0)
		slot_label.text = "Slot %s" % [slot_index + 1]
		slot_label.add_theme_color_override("font_color", PANEL_TEXT_COLOR)
		row.add_child(slot_label)

		var option: OptionButton = OptionButton.new()
		option.custom_minimum_size = Vector2(190.0, 0.0)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_button_text_colors(option)
		option.item_selected.connect(_on_loadout_option_selected.bind(slot_index))
		row.add_child(option)

		var enabled_check_box: CheckBox = CheckBox.new()
		enabled_check_box.text = "Enabled"
		_apply_button_text_colors(enabled_check_box)
		enabled_check_box.toggled.connect(_on_loadout_enabled_toggled.bind(slot_index))
		row.add_child(enabled_check_box)

		_ability_slot_rows.append({
			"option": option,
			"enabled": enabled_check_box,
			"slot_index": slot_index,
		})

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	panel_vbox.add_child(action_row)

	var save_button: Button = Button.new()
	save_button.text = "Save Loadout"
	_apply_button_text_colors(save_button)
	save_button.pressed.connect(_on_save_loadout_pressed)
	action_row.add_child(save_button)

	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	_apply_button_text_colors(cancel_button)
	cancel_button.pressed.connect(_on_cancel_loadout_pressed)
	action_row.add_child(cancel_button)

	_ability_panel_status = _add_label(panel_vbox, "")
	_refresh_ability_panel_options()


func _build_inventory_panel() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.visible = false
	_inventory_panel.anchor_left = 1.0
	_inventory_panel.anchor_right = 1.0
	_inventory_panel.offset_left = -696.0
	_inventory_panel.offset_top = 556.0
	_inventory_panel.offset_right = -16.0
	_inventory_panel.offset_bottom = 760.0
	_inventory_panel.custom_minimum_size = Vector2(680.0, 204.0)
	_apply_panel_style(_inventory_panel)
	_root.add_child(_inventory_panel)

	var panel_vbox: VBoxContainer = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 6)
	panel_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_panel.add_child(panel_vbox)

	var title_label: Label = _add_title_label(panel_vbox, "Inventory")
	title_label.gui_input.connect(_on_panel_drag_handle_input.bind(_inventory_panel))

	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 10)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_vbox.add_child(content_row)

	var inventory_scroll: ScrollContainer = ScrollContainer.new()
	inventory_scroll.name = "InventoryScroll"
	inventory_scroll.custom_minimum_size = Vector2(310.0, 0.0)
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_row.add_child(inventory_scroll)

	_inventory_list = VBoxContainer.new()
	_inventory_list.add_theme_constant_override("separation", 4)
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(_inventory_list)

	var comparison_panel: PanelContainer = PanelContainer.new()
	comparison_panel.custom_minimum_size = Vector2(330.0, 0.0)
	comparison_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_section_panel_style(comparison_panel)
	content_row.add_child(comparison_panel)

	var comparison_vbox: VBoxContainer = VBoxContainer.new()
	comparison_vbox.add_theme_constant_override("separation", 4)
	comparison_panel.add_child(comparison_vbox)

	_add_label(comparison_vbox, "Comparison")
	_inventory_comparison_label = _add_label(comparison_vbox, "")
	_inventory_comparison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_inventory_panel()
	_refresh_inventory_comparison()


func _add_label(parent: Control, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.layout_mode = 2
	label.add_theme_color_override("font_color", PANEL_TEXT_COLOR)
	parent.add_child(label)
	return label


func _add_title_label(parent: Control, text: String) -> Label:
	var label: Label = _add_label(parent, text)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.add_theme_font_size_override("font_size", 16)
	return label


func _add_button(parent: Control, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	_apply_button_text_colors(button)
	parent.add_child(button)
	return button


func _apply_panel_style(panel: PanelContainer) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = PANEL_BACKGROUND_COLOR
	style_box.border_color = PANEL_BORDER_COLOR
	style_box.set_border_width_all(1)
	style_box.set_content_margin(SIDE_LEFT, 8.0)
	style_box.set_content_margin(SIDE_TOP, 8.0)
	style_box.set_content_margin(SIDE_RIGHT, 8.0)
	style_box.set_content_margin(SIDE_BOTTOM, 8.0)
	panel.add_theme_stylebox_override("panel", style_box)


func _apply_section_panel_style(panel: PanelContainer) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.09, 0.10, 0.86)
	style_box.border_color = Color(0.26, 0.28, 0.31, 0.9)
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin(SIDE_LEFT, 8.0)
	style_box.set_content_margin(SIDE_TOP, 8.0)
	style_box.set_content_margin(SIDE_RIGHT, 8.0)
	style_box.set_content_margin(SIDE_BOTTOM, 8.0)
	panel.add_theme_stylebox_override("panel", style_box)


func _apply_slot_panel_style(panel: PanelContainer) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.12, 0.13, 0.15, 0.9)
	style_box.border_color = Color(0.36, 0.38, 0.42, 0.95)
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin(SIDE_LEFT, 5.0)
	style_box.set_content_margin(SIDE_TOP, 4.0)
	style_box.set_content_margin(SIDE_RIGHT, 5.0)
	style_box.set_content_margin(SIDE_BOTTOM, 4.0)
	panel.add_theme_stylebox_override("panel", style_box)


func _apply_button_text_colors(button: BaseButton) -> void:
	button.add_theme_color_override("font_color", PANEL_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", PANEL_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", PANEL_TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", PANEL_TEXT_COLOR)


func _rebuild_ability_controls() -> void:
	for child in _ability_list.get_children():
		_ability_list.remove_child(child)
		child.queue_free()
	_ability_check_box_by_name.clear()

	for ability_name in _confirmed_loadout:
		var check_box: CheckBox = CheckBox.new()
		check_box.focus_mode = Control.FOCUS_NONE
		_apply_button_text_colors(check_box)
		check_box.toggled.connect(_on_ability_check_box_toggled.bind(ability_name))
		_ability_list.add_child(check_box)
		_ability_check_box_by_name[ability_name] = check_box
		_update_ability_display(ability_name)


func _refresh_hotbar() -> void:
	_refresh_weapon_primary_button()
	for slot_index in range(HOTBAR_SLOT_COUNT):
		var button: Button = _hotbar_button_by_slot[slot_index] as Button
		var entry: Dictionary = _loadout_entry_for_slot(slot_index)
		if entry.is_empty():
			button.disabled = true
			button.text = "%s\nEmpty" % [slot_index + 1]
			continue

		button.disabled = false
		var ability_name: String = str(entry.get("ability_name", ""))
		button.text = _ability_hotbar_text(slot_index, ability_name)


func _refresh_weapon_primary_button() -> void:
	if _weapon_primary_button == null:
		return

	var ability_name: String = _weapon_primary_ability_name()
	if ability_name == "":
		_weapon_primary_button.disabled = true
		_weapon_primary_button.text = "Weapon\nNone"
		return

	_weapon_primary_button.disabled = false
	_weapon_primary_button.text = "Weapon\n%s" % _weapon_primary_hotbar_text(ability_name)


func _weapon_primary_ability_name() -> String:
	return str(_weapon_primary_ability.get("ability_name", "")).strip_edges()


func _weapon_primary_hotbar_text(ability_name: String) -> String:
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	var active: bool = bool(state.get("active", false))
	var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
	if cooldown_remaining > 0.05:
		return "%s\nCD %.1fs" % [_weapon_primary_display_name(ability_name), cooldown_remaining]
	return "%s\n%s" % [_weapon_primary_display_name(ability_name), "active" if active else "ready"]


func _weapon_primary_display_name(ability_name: String) -> String:
	var display_name: String = str(_weapon_primary_ability.get("display_name", _ability_display_name_by_name.get(ability_name, ability_name))).strip_edges()
	return display_name if display_name != "" else ability_name


func _refresh_character_panel() -> void:
	if _character_level_label == null:
		return

	_character_level_label.text = "Level: %s" % _current_level
	var xp_to_next_text: String = str(_current_xp_to_next) if _current_xp_to_next > 0 else "--"
	_character_xp_label.text = "XP: %s/%s" % [_current_xp, xp_to_next_text]
	_character_gold_label.text = "Gold: %s" % _current_gold
	if not _has_confirmed_combat_stats:
		_character_max_hp_label.text = "Max HP: --"
		_character_move_speed_label.text = "Move Speed: --"
		_character_physical_power_label.text = "Physical Power: --"
		_character_spell_power_label.text = "Spell Power: --"
		_character_armor_label.text = "Armor: --"
		_character_avoidance_label.text = "Avoidance: --"
	else:
		_character_max_hp_label.text = "Max HP: %s" % _current_max_hp
		_character_move_speed_label.text = "Move Speed: %s" % _format_stat_number(_current_move_speed)
		_character_physical_power_label.text = "Physical Power: %s" % _format_stat_number(_current_physical_power)
		_character_spell_power_label.text = "Spell Power: %s" % _format_stat_number(_current_spell_power)
		_character_armor_label.text = "Armor: %s%%" % int(round(_current_armor * 100.0))
		_character_avoidance_label.text = "Avoidance: %s%%" % int(round(_current_avoidance * 100.0))
	for slot_name in EQUIPMENT_SLOTS:
		if not _equipment_slot_labels.has(slot_name):
			continue

		var slot_label: Label = _equipment_slot_labels[slot_name] as Label
		slot_label.text = _equipment_display_text(slot_name)


func _equipment_display_text(slot_name: String) -> String:
	var slot_data: Variant = _confirmed_equipment.get(slot_name, {})
	if not (slot_data is Dictionary):
		return "Empty"

	var equipment_item: Dictionary = slot_data as Dictionary
	if equipment_item.is_empty():
		return "Empty"

	var display_name: String = str(equipment_item.get("display_name", "")).strip_edges()
	var item_key: String = str(equipment_item.get("item_key", "")).strip_edges()
	var label_text: String = display_name if display_name != "" else item_key
	if label_text == "":
		return "Empty"

	return label_text


func _format_stat_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))

	return "%.1f" % value


func _refresh_equipment_slot_options() -> void:
	_is_refreshing_equipment_ui = true
	for slot_name in EQUIPMENT_SLOTS:
		if not _equipment_slot_options.has(slot_name):
			continue

		var option: OptionButton = _equipment_slot_options[slot_name] as OptionButton
		var confirmed_inventory_entry_id: String = _confirmed_inventory_entry_id_for_slot(slot_name)
		option.clear()
		option.add_item("Empty / Unequip")
		option.set_item_metadata(0, null)

		var confirmed_item: Dictionary = _confirmed_equipment_item_for_slot(slot_name)
		if not confirmed_item.is_empty():
			_add_equipment_option(option, confirmed_item, -1)

		var equipped_other_slot_entry_ids: Array[String] = _confirmed_equipped_inventory_entry_ids_except(slot_name)
		for item_variant in _eligible_inventory_items_for_slot(slot_name):
			if not (item_variant is Dictionary):
				continue

			var item: Dictionary = item_variant as Dictionary
			var item_key: String = str(item.get("item_key", "")).strip_edges()
			if item_key == "":
				continue
			var inventory_entry_id: String = _inventory_entry_id(item)
			if inventory_entry_id != "" and equipped_other_slot_entry_ids.has(inventory_entry_id):
				continue

			_add_equipment_option(option, item, max(int(item.get("quantity", 0)), 0))

		_select_equipment_option(option, confirmed_inventory_entry_id, _confirmed_item_key_for_slot(slot_name))
		option.disabled = _is_equipment_change_pending
	_is_refreshing_equipment_ui = false


func _confirmed_inventory_entry_id_for_slot(slot_name: String) -> String:
	var slot_data: Variant = _confirmed_equipment.get(slot_name, {})
	if not (slot_data is Dictionary):
		return ""

	return _inventory_entry_id(slot_data as Dictionary)


func _confirmed_item_key_for_slot(slot_name: String) -> String:
	var slot_data: Variant = _confirmed_equipment.get(slot_name, {})
	if not (slot_data is Dictionary):
		return ""

	return str((slot_data as Dictionary).get("item_key", "")).strip_edges()


func _confirmed_equipment_item_for_slot(slot_name: String) -> Dictionary:
	var slot_data: Variant = _confirmed_equipment.get(slot_name, {})
	if not (slot_data is Dictionary):
		return {}

	return (slot_data as Dictionary).duplicate(true)


func _add_equipment_option(option: OptionButton, item: Dictionary, quantity: int) -> void:
	var inventory_entry_id: String = _inventory_entry_id(item)
	var item_key: String = str(item.get("item_key", "")).strip_edges()
	if item_key == "":
		return

	for item_index in range(option.get_item_count()):
		if _equipment_metadata_matches_item(option.get_item_metadata(item_index), inventory_entry_id, item_key):
			return

	var display_name: String = _equipment_item_display_name(item, item_key)
	var option_text: String = display_name if display_name != "" else item_key
	if quantity >= 0 and _inventory_item_shows_quantity(item):
		option_text = "%s x%s" % [option_text, quantity]
	option.add_item(option_text)
	option.set_item_metadata(option.get_item_count() - 1, {
		"inventory_entry_id": inventory_entry_id,
		"item_key": item_key,
	})


func _equipment_item_display_name(item: Dictionary, item_key: String) -> String:
	var display_name: String = str(item.get("display_name", "")).strip_edges()
	if display_name != "":
		return display_name

	return item_key


func _eligible_inventory_items_for_slot(slot_name: String) -> Array:
	var eligible_items: Array = []
	for item_variant in _confirmed_inventory_items:
		if not (item_variant is Dictionary):
			continue

		var item: Dictionary = item_variant as Dictionary
		if _inventory_item_equip_slot(item) != slot_name:
			continue
		if int(item.get("quantity", 0)) <= 0:
			continue
		eligible_items.append(item)

	return eligible_items


func _inventory_entry_id(item: Dictionary) -> String:
	var inventory_entry_id: String = str(item.get("inventory_entry_id", item.get("entry_id", item.get("inventory_item_id", "")))).strip_edges()
	if inventory_entry_id != "":
		return inventory_entry_id

	if item.get("item", null) is Dictionary:
		var nested_item: Dictionary = item.get("item", {}) as Dictionary
		inventory_entry_id = str(nested_item.get("inventory_entry_id", nested_item.get("entry_id", nested_item.get("inventory_item_id", "")))).strip_edges()
		if inventory_entry_id != "":
			return inventory_entry_id

	return str(item.get("id", "")).strip_edges()


func _inventory_item_equip_slot(item: Dictionary) -> String:
	var slot_name: String = str(item.get("equip_slot", item.get("equipment_slot", item.get("slot", "")))).strip_edges().to_lower()
	if slot_name != "":
		return slot_name

	if item.get("definition", null) is Dictionary:
		var definition: Dictionary = item.get("definition", {}) as Dictionary
		slot_name = str(definition.get("equip_slot", definition.get("equipment_slot", definition.get("slot", "")))).strip_edges().to_lower()
		if slot_name != "":
			return slot_name

	if item.get("item", null) is Dictionary:
		var nested_item: Dictionary = item.get("item", {}) as Dictionary
		slot_name = str(nested_item.get("equip_slot", nested_item.get("equipment_slot", nested_item.get("slot", "")))).strip_edges().to_lower()
		if slot_name != "":
			return slot_name
		if nested_item.get("definition", null) is Dictionary:
			var nested_definition: Dictionary = nested_item.get("definition", {}) as Dictionary
			slot_name = str(nested_definition.get("equip_slot", nested_definition.get("equipment_slot", nested_definition.get("slot", "")))).strip_edges().to_lower()

	return slot_name


func _select_equipment_option(option: OptionButton, inventory_entry_id: String, item_key: String = "") -> void:
	for item_index in range(option.get_item_count()):
		var metadata: Variant = option.get_item_metadata(item_index)
		var metadata_entry_id: String = _equipment_metadata_inventory_entry_id(metadata)
		if inventory_entry_id != "" and metadata_entry_id == inventory_entry_id:
			option.select(item_index)
			return
		if inventory_entry_id == "" and _equipment_metadata_item_key(metadata) == item_key:
			option.select(item_index)
			return

	option.select(0)


func _equipment_metadata_matches_item(metadata: Variant, inventory_entry_id: String, item_key: String) -> bool:
	var metadata_entry_id: String = _equipment_metadata_inventory_entry_id(metadata)
	if inventory_entry_id != "" and metadata_entry_id != "":
		return metadata_entry_id == inventory_entry_id

	return inventory_entry_id == "" and _equipment_metadata_item_key(metadata) == item_key


func _equipment_metadata_inventory_entry_id(metadata: Variant) -> String:
	if metadata == null:
		return ""
	if metadata is Dictionary:
		return _inventory_entry_id(metadata as Dictionary)

	return ""


func _equipment_metadata_item_key(metadata: Variant) -> String:
	if metadata == null:
		return ""
	if metadata is Dictionary:
		return str((metadata as Dictionary).get("item_key", "")).strip_edges()

	return str(metadata).strip_edges()


func _refresh_inventory_panel() -> void:
	if _inventory_list == null:
		return

	for child in _inventory_list.get_children():
		_inventory_list.remove_child(child)
		child.queue_free()

	if _confirmed_inventory_items.is_empty():
		_add_label(_inventory_list, "No confirmed items yet.")
		return

	var visible_item_count: int = 0
	var equipped_inventory_entry_ids: Array[String] = _confirmed_equipped_inventory_entry_ids()
	for item_variant in _confirmed_inventory_items:
		if not (item_variant is Dictionary):
			continue

		var item: Dictionary = item_variant as Dictionary
		var item_key: String = str(item.get("item_key", "")).strip_edges()
		var inventory_entry_id: String = _inventory_entry_id(item)
		if inventory_entry_id != "" and equipped_inventory_entry_ids.has(inventory_entry_id):
			continue

		_add_inventory_row(_inventory_list, item, _inventory_item_display_text(item, item_key))
		visible_item_count += 1

	if visible_item_count == 0:
		_add_label(_inventory_list, "No unequipped items.")


func _add_inventory_row(parent: Control, item: Dictionary, text: String) -> void:
	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	if _inventory_item_matches_selection(item):
		row_style.bg_color = Color(0.16, 0.18, 0.22, 0.94)
		row_style.border_color = Color(0.60, 0.66, 0.74, 0.95)
	else:
		row_style.bg_color = Color(0.11, 0.12, 0.14, 0.88)
		row_style.border_color = Color(0.28, 0.30, 0.34, 0.9)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin(SIDE_LEFT, 8.0)
	row_style.set_content_margin(SIDE_TOP, 5.0)
	row_style.set_content_margin(SIDE_RIGHT, 8.0)
	row_style.set_content_margin(SIDE_BOTTOM, 5.0)
	row_panel.add_theme_stylebox_override("panel", row_style)
	row_panel.gui_input.connect(_on_inventory_row_input.bind(item.duplicate(true)))
	parent.add_child(row_panel)

	var label: Label = _add_label(row_panel, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _inventory_item_display_text(item: Dictionary, item_key: String) -> String:
	var display_name: String = str(item.get("display_name", item_key)).strip_edges()
	if display_name == "":
		display_name = item_key

	if _inventory_item_shows_quantity(item):
		var quantity: int = max(int(item.get("quantity", 0)), 0)
		return "%s x%s" % [display_name, quantity]

	return display_name


func _inventory_item_shows_quantity(item: Dictionary) -> bool:
	var stackable_flag: Variant = _inventory_item_stackable_flag(item)
	if stackable_flag != null:
		return _variant_is_true(stackable_flag)

	return _inventory_item_equip_slot(item) == ""


func _variant_is_true(value: Variant) -> bool:
	if value is bool:
		return bool(value)
	if value is int:
		return int(value) != 0
	if value is float:
		return not is_zero_approx(float(value))

	var value_text: String = str(value).strip_edges().to_lower()
	return value_text == "true" or value_text == "yes" or value_text == "1"


func _inventory_item_stackable_flag(item: Dictionary) -> Variant:
	for key in ["stackable", "is_stackable"]:
		if item.has(key):
			return item[key]

	if item.get("definition", null) is Dictionary:
		var definition: Dictionary = item.get("definition", {}) as Dictionary
		for key in ["stackable", "is_stackable"]:
			if definition.has(key):
				return definition[key]

	if item.get("item", null) is Dictionary:
		var nested_item: Dictionary = item.get("item", {}) as Dictionary
		for key in ["stackable", "is_stackable"]:
			if nested_item.has(key):
				return nested_item[key]
		if nested_item.get("definition", null) is Dictionary:
			var nested_definition: Dictionary = nested_item.get("definition", {}) as Dictionary
			for key in ["stackable", "is_stackable"]:
				if nested_definition.has(key):
					return nested_definition[key]

	return null


func _refresh_selected_inventory_item() -> void:
	if _selected_inventory_item.is_empty():
		return

	var selected_inventory_entry_id: String = _inventory_entry_id(_selected_inventory_item)
	var selected_item_key: String = str(_selected_inventory_item.get("item_key", "")).strip_edges()
	for item_variant in _confirmed_inventory_items:
		if not (item_variant is Dictionary):
			continue

		var item: Dictionary = item_variant as Dictionary
		if selected_inventory_entry_id != "" and _inventory_entry_id(item) == selected_inventory_entry_id:
			_selected_inventory_item = item.duplicate(true)
			return
		if selected_inventory_entry_id == "" and selected_item_key != "" and str(item.get("item_key", "")).strip_edges() == selected_item_key:
			_selected_inventory_item = item.duplicate(true)
			return

	_selected_inventory_item.clear()


func _inventory_item_matches_selection(item: Dictionary) -> bool:
	if _selected_inventory_item.is_empty():
		return false

	var inventory_entry_id: String = _inventory_entry_id(item)
	var selected_inventory_entry_id: String = _inventory_entry_id(_selected_inventory_item)
	if inventory_entry_id != "" or selected_inventory_entry_id != "":
		return inventory_entry_id != "" and inventory_entry_id == selected_inventory_entry_id

	return str(item.get("item_key", "")).strip_edges() == str(_selected_inventory_item.get("item_key", "")).strip_edges()


func _refresh_inventory_comparison() -> void:
	if _inventory_comparison_label == null:
		return

	if _selected_inventory_item.is_empty():
		_inventory_comparison_label.text = "Select an item to compare."
		return

	var selected_item: Dictionary = _selected_inventory_item
	var selected_name: String = _item_player_name(selected_item)
	var selected_slot: String = _inventory_item_equip_slot(selected_item)
	var comparison_lines: Array[String] = [
		"Selected Item:",
		selected_name,
	]

	if selected_slot == "":
		if _inventory_item_shows_quantity(selected_item):
			comparison_lines.append("Quantity: %s" % max(int(selected_item.get("quantity", 0)), 0))
		comparison_lines.append("")
		comparison_lines.append("Not equippable.")
		_inventory_comparison_label.text = "\n".join(comparison_lines)
		return

	var selected_stats: Dictionary = _item_stat_values(selected_item)
	comparison_lines.append("Slot: %s" % str(EQUIPMENT_SLOT_LABELS.get(selected_slot, selected_slot.capitalize())))
	comparison_lines.append_array(_formatted_item_stat_lines(selected_stats))
	comparison_lines.append("")
	comparison_lines.append("Currently Equipped:")

	var equipped_item: Dictionary = _confirmed_equipment_item_for_slot(selected_slot)
	var equipped_stats: Dictionary = {}
	if equipped_item.is_empty():
		comparison_lines.append("Empty")
	else:
		comparison_lines.append(_item_player_name(equipped_item))
		equipped_stats = _item_stat_values(equipped_item)
		comparison_lines.append_array(_formatted_item_stat_lines(equipped_stats))

	var delta_lines: Array[String] = _formatted_item_delta_lines(selected_stats, equipped_stats)
	if not delta_lines.is_empty():
		comparison_lines.append("")
		comparison_lines.append("Difference:")
		comparison_lines.append_array(delta_lines)

	_inventory_comparison_label.text = "\n".join(comparison_lines)


func _item_player_name(item: Dictionary) -> String:
	var display_name: String = str(item.get("display_name", "")).strip_edges()
	if display_name != "":
		return display_name

	if item.get("definition", null) is Dictionary:
		display_name = str((item.get("definition", {}) as Dictionary).get("display_name", "")).strip_edges()
		if display_name != "":
			return display_name

	if item.get("item", null) is Dictionary:
		var nested_item: Dictionary = item.get("item", {}) as Dictionary
		display_name = str(nested_item.get("display_name", "")).strip_edges()
		if display_name != "":
			return display_name
		if nested_item.get("definition", null) is Dictionary:
			display_name = str((nested_item.get("definition", {}) as Dictionary).get("display_name", "")).strip_edges()
			if display_name != "":
				return display_name

	return "Unnamed Item"


func _item_stat_values(item: Dictionary) -> Dictionary:
	var stat_values: Dictionary = {}
	for modifier_variant in _item_stat_modifiers(item):
		if not (modifier_variant is Dictionary):
			continue

		var modifier: Dictionary = modifier_variant as Dictionary
		var stat_key: String = str(modifier.get("stat_key", modifier.get("key", modifier.get("stat", modifier.get("attribute", ""))))).strip_edges().to_lower()
		stat_key = str(ITEM_STAT_ALIASES.get(stat_key, stat_key))
		if not ITEM_STAT_LABELS.has(stat_key):
			continue

		var value: float = float(modifier.get("value", modifier.get("amount", 0.0)))
		if is_zero_approx(value):
			continue

		stat_values[stat_key] = float(stat_values.get(stat_key, 0.0)) + value

	return stat_values


func _item_stat_modifiers(item: Dictionary) -> Array:
	var modifiers: Array = []
	for container_variant in _item_stat_modifier_containers(item):
		if not (container_variant is Dictionary):
			continue

		var container: Dictionary = container_variant as Dictionary
		var raw_modifiers: Variant = container.get("stat_modifiers", container.get("modifiers", container.get("stats", [])))
		if raw_modifiers is Array:
			modifiers.append_array(raw_modifiers as Array)
		elif raw_modifiers is Dictionary:
			var raw_modifier_dictionary: Dictionary = raw_modifiers as Dictionary
			for stat_key in raw_modifier_dictionary.keys():
				modifiers.append({
					"stat_key": str(stat_key),
					"value": raw_modifier_dictionary[stat_key],
				})

	return modifiers


func _item_stat_modifier_containers(item: Dictionary) -> Array:
	var containers: Array = [item]
	if item.get("definition", null) is Dictionary:
		containers.append(item.get("definition", {}) as Dictionary)
	if item.get("item_definition", null) is Dictionary:
		containers.append(item.get("item_definition", {}) as Dictionary)
	if item.get("item", null) is Dictionary:
		var nested_item: Dictionary = item.get("item", {}) as Dictionary
		containers.append(nested_item)
		if nested_item.get("definition", null) is Dictionary:
			containers.append(nested_item.get("definition", {}) as Dictionary)
		if nested_item.get("item_definition", null) is Dictionary:
			containers.append(nested_item.get("item_definition", {}) as Dictionary)

	return containers


func _formatted_item_stat_lines(stat_values: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for stat_key in ITEM_STAT_DISPLAY_ORDER:
		if not stat_values.has(stat_key):
			continue

		lines.append(_format_item_stat_line(stat_key, float(stat_values[stat_key])))

	if lines.is_empty():
		lines.append("No stat modifiers.")

	return lines


func _formatted_item_delta_lines(selected_stats: Dictionary, equipped_stats: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for stat_key in _item_delta_stat_keys(selected_stats, equipped_stats):
		var selected_value: float = float(selected_stats.get(stat_key, 0.0))
		var equipped_value: float = float(equipped_stats.get(stat_key, 0.0))
		var delta: float = selected_value - equipped_value
		if is_zero_approx(delta):
			continue

		lines.append("%s: %s" % [
			str(ITEM_STAT_LABELS.get(stat_key, stat_key.capitalize())),
			_format_item_stat_value(stat_key, delta),
		])

	return lines


func _item_delta_stat_keys(selected_stats: Dictionary, equipped_stats: Dictionary) -> Array[String]:
	var stat_keys: Array[String] = []
	for stat_key in ITEM_STAT_DISPLAY_ORDER:
		if selected_stats.has(stat_key) or equipped_stats.has(stat_key):
			stat_keys.append(stat_key)
	for selected_stat_key_variant in selected_stats.keys():
		var selected_stat_key: String = str(selected_stat_key_variant)
		if not stat_keys.has(selected_stat_key):
			stat_keys.append(selected_stat_key)
	for equipped_stat_key_variant in equipped_stats.keys():
		var equipped_stat_key: String = str(equipped_stat_key_variant)
		if not stat_keys.has(equipped_stat_key):
			stat_keys.append(equipped_stat_key)
	return stat_keys


func _format_item_stat_line(stat_key: String, value: float) -> String:
	return "%s %s" % [_format_item_stat_value(stat_key, value), str(ITEM_STAT_LABELS.get(stat_key, stat_key.capitalize()))]


func _format_item_stat_value(stat_key: String, value: float) -> String:
	var sign: String = "+" if value > 0.0 else ""
	if stat_key == "avoidance":
		return "%s%s%%" % [sign, _format_stat_number(value * 100.0)]

	return "%s%s" % [sign, _format_stat_number(value)]


func _confirmed_equipped_inventory_entry_ids() -> Array[String]:
	var equipped_inventory_entry_ids: Array[String] = []
	for slot_name in EQUIPMENT_SLOTS:
		var inventory_entry_id: String = _confirmed_inventory_entry_id_for_slot(slot_name)
		if inventory_entry_id != "" and not equipped_inventory_entry_ids.has(inventory_entry_id):
			equipped_inventory_entry_ids.append(inventory_entry_id)

	return equipped_inventory_entry_ids


func _confirmed_equipped_inventory_entry_ids_except(excluded_slot_name: String) -> Array[String]:
	var equipped_inventory_entry_ids: Array[String] = []
	for slot_name in EQUIPMENT_SLOTS:
		if slot_name == excluded_slot_name:
			continue

		var inventory_entry_id: String = _confirmed_inventory_entry_id_for_slot(slot_name)
		if inventory_entry_id != "" and not equipped_inventory_entry_ids.has(inventory_entry_id):
			equipped_inventory_entry_ids.append(inventory_entry_id)

	return equipped_inventory_entry_ids


func _refresh_ability_panel_options() -> void:
	var selected_keys_by_slot: Dictionary = _selected_ability_keys_by_slot()
	for row_variant in _ability_slot_rows:
		var row: Dictionary = row_variant as Dictionary
		var slot_index: int = int(row.get("slot_index", 0))
		var option: OptionButton = row["option"] as OptionButton
		var current_key: String = str(selected_keys_by_slot.get(slot_index, "")).strip_edges()
		var blocked_keys: Array[String] = _blocked_ability_keys_for_slot(slot_index, selected_keys_by_slot)
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
			if ability_key != current_key and blocked_keys.has(ability_key):
				continue

			var display_name: String = str(ability.get("display_name", ability_key)).strip_edges()
			option.add_item(display_name if display_name != "" else ability_key)
			option.set_item_metadata(option.get_item_count() - 1, ability_key)

		_select_ability_option(option, current_key)


func _refresh_ability_panel_rows() -> void:
	if _ability_slot_rows.is_empty():
		return

	for slot_index in range(_ability_slot_rows.size()):
		var row: Dictionary = _ability_slot_rows[slot_index] as Dictionary
		var option: OptionButton = row["option"] as OptionButton
		var enabled_check_box: CheckBox = row["enabled"] as CheckBox
		var entry: Dictionary = _panel_loadout_entry_for_slot(slot_index)
		var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
		_select_ability_option(option, ability_key)
		enabled_check_box.set_pressed_no_signal(bool(entry.get("enabled", true)))

	_refresh_ability_panel_options()


func _select_ability_option(option: OptionButton, ability_key: String) -> void:
	for item_index in range(option.get_item_count()):
		if str(option.get_item_metadata(item_index)) == ability_key:
			option.select(item_index)
			return

	option.select(0)


func _selected_ability_keys_by_slot() -> Dictionary:
	var selected_keys_by_slot: Dictionary = {}
	for slot_index in range(_ability_slot_rows.size()):
		var selected_key: String = str(_panel_loadout_entry_for_slot(slot_index).get("ability_key", "")).strip_edges()
		if selected_key == "" and not _is_loadout_draft_active:
			var row: Dictionary = _ability_slot_rows[slot_index] as Dictionary
			var option: OptionButton = row["option"] as OptionButton
			if option.get_item_count() > 0 and option.selected >= 0:
				selected_key = str(option.get_item_metadata(option.selected)).strip_edges()

		selected_keys_by_slot[slot_index] = selected_key

	return selected_keys_by_slot


func _blocked_ability_keys_for_slot(slot_index: int, selected_keys_by_slot: Dictionary) -> Array[String]:
	var blocked_keys: Array[String] = []
	for other_slot_variant in selected_keys_by_slot.keys():
		var other_slot_index: int = int(other_slot_variant)
		if other_slot_index == slot_index:
			continue

		var selected_key: String = str(selected_keys_by_slot[other_slot_variant]).strip_edges()
		if selected_key != "" and not blocked_keys.has(selected_key):
			blocked_keys.append(selected_key)

	if _is_loadout_draft_active:
		return blocked_keys

	for entry_variant in _confirmed_loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		if int(entry.get("slot_index", 0)) == slot_index:
			continue

		var confirmed_key: String = str(entry.get("ability_key", "")).strip_edges()
		if confirmed_key != "" and not blocked_keys.has(confirmed_key):
			blocked_keys.append(confirmed_key)

	return blocked_keys


func _update_confirmed_loadout_entry_enabled(ability_name: String, enabled: bool) -> void:
	for entry_index in range(_confirmed_loadout_entries.size()):
		var entry: Dictionary = _confirmed_loadout_entries[entry_index] as Dictionary
		if str(entry.get("ability_name", "")) == ability_name:
			entry["enabled"] = enabled
			_confirmed_loadout_entries[entry_index] = entry
			return


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

	var display_name: String = str(_ability_display_name_by_name.get(ability_name, ability_name))
	if _ability_check_box_by_name.has(ability_name):
		var check_box: CheckBox = _ability_check_box_by_name[ability_name] as CheckBox
		check_box.set_pressed_no_signal(enabled)
		check_box.text = "%s: %s | %s%s" % [display_name, enabled_text, active_text, cooldown_text]
	_refresh_hotbar()


func _ability_hotbar_text(slot_index: int, ability_name: String) -> String:
	var state: Dictionary = _ability_state_by_name.get(ability_name, {}) as Dictionary
	var enabled: bool = bool(state.get("enabled", _ability_enabled_by_name.get(ability_name, true)))
	var active: bool = bool(state.get("active", false))
	var cooldown_remaining: float = float(state.get("cooldown_remaining", 0.0))
	var enabled_text: String = "ON" if enabled else "OFF"
	var status_text: String = "active" if active else "ready"
	if cooldown_remaining > 0.05:
		status_text = "CD %.1fs" % cooldown_remaining

	var display_name: String = str(_ability_display_name_by_name.get(ability_name, ability_name))
	return "%s\n%s\n%s | %s" % [slot_index + 1, display_name, enabled_text, status_text]


func _loadout_entry_for_slot(slot_index: int) -> Dictionary:
	for entry_variant in _confirmed_loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		if int(entry.get("slot_index", 0)) == slot_index:
			return entry

	return {}


func _panel_loadout_entry_for_slot(slot_index: int) -> Dictionary:
	if _is_loadout_draft_active:
		return _draft_loadout_entry_for_slot(slot_index)

	return _loadout_entry_for_slot(slot_index)


func _draft_loadout_entry_for_slot(slot_index: int) -> Dictionary:
	for entry_variant in _draft_loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		if int(entry.get("slot_index", 0)) == slot_index:
			return entry

	return {}


func _begin_loadout_draft() -> void:
	_is_loadout_draft_active = true
	_is_loadout_draft_dirty = false
	_is_loadout_save_pending = false
	_pending_loadout_entries.clear()
	_initialize_loadout_draft_from_confirmed()
	_refresh_ability_panel_options()
	_refresh_ability_panel_rows()
	if _ability_panel_status != null:
		_ability_panel_status.text = ""


func _cancel_loadout_draft() -> void:
	_is_loadout_draft_active = false
	_is_loadout_draft_dirty = false
	_is_loadout_save_pending = false
	_draft_loadout_entries.clear()
	_pending_loadout_entries.clear()
	_refresh_ability_panel_options()
	_refresh_ability_panel_rows()
	if _ability_panel_status != null:
		_ability_panel_status.text = ""


func _initialize_loadout_draft_from_confirmed() -> void:
	_draft_loadout_entries = _duplicate_loadout_entries(_confirmed_loadout_entries)


func _duplicate_loadout_entries(loadout_entries: Array) -> Array:
	var duplicate_entries: Array = []
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		duplicate_entries.append((entry_variant as Dictionary).duplicate())

	return duplicate_entries


func _set_draft_loadout_entry(slot_index: int, ability_key: String, enabled: bool) -> void:
	for entry_index in range(_draft_loadout_entries.size()):
		var entry: Dictionary = _draft_loadout_entries[entry_index] as Dictionary
		if int(entry.get("slot_index", 0)) == slot_index:
			if ability_key == "":
				_draft_loadout_entries.remove_at(entry_index)
			else:
				_draft_loadout_entries[entry_index] = _draft_entry_for_ability_key(slot_index, ability_key, enabled)
			return

	if ability_key != "":
		_draft_loadout_entries.append(_draft_entry_for_ability_key(slot_index, ability_key, enabled))


func _draft_entry_for_ability_key(slot_index: int, ability_key: String, enabled: bool) -> Dictionary:
	var entry: Dictionary = {
		"slot_index": slot_index,
		"ability_key": ability_key,
		"enabled": enabled,
	}
	var ability: Dictionary = _unlocked_ability_for_key(ability_key)
	if not ability.is_empty():
		entry["ability_name"] = str(ability.get("ability_name", ""))
		entry["display_name"] = str(ability.get("display_name", ability_key))

	return entry


func _unlocked_ability_for_key(ability_key: String) -> Dictionary:
	for ability_variant in _unlocked_abilities:
		if not (ability_variant is Dictionary):
			continue

		var ability: Dictionary = ability_variant as Dictionary
		if str(ability.get("ability_key", "")).strip_edges() == ability_key:
			return ability

	return {}


func _loadout_entries_match(left_entries: Array, right_entries: Array) -> bool:
	var left_by_slot: Dictionary = _loadout_entries_by_slot(left_entries)
	var right_by_slot: Dictionary = _loadout_entries_by_slot(right_entries)
	if left_by_slot.size() != right_by_slot.size():
		return false

	for slot_variant in left_by_slot.keys():
		if not right_by_slot.has(slot_variant):
			return false

		var left_entry: Dictionary = left_by_slot[slot_variant] as Dictionary
		var right_entry: Dictionary = right_by_slot[slot_variant] as Dictionary
		if str(left_entry.get("ability_key", "")).strip_edges() != str(right_entry.get("ability_key", "")).strip_edges():
			return false
		if bool(left_entry.get("enabled", true)) != bool(right_entry.get("enabled", true)):
			return false

	return true


func _loadout_entries_by_slot(loadout_entries: Array) -> Dictionary:
	var entries_by_slot: Dictionary = {}
	for entry_variant in loadout_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
		if ability_key == "":
			continue

		entries_by_slot[int(entry.get("slot_index", 0))] = entry

	return entries_by_slot


func _on_loadout_option_selected(item_index: int, slot_index: int) -> void:
	if not _is_loadout_draft_active:
		_begin_loadout_draft()

	var row: Dictionary = _ability_slot_rows[slot_index] as Dictionary
	var option: OptionButton = row["option"] as OptionButton
	var enabled_check_box: CheckBox = row["enabled"] as CheckBox
	var ability_key: String = ""
	if item_index >= 0 and item_index < option.get_item_count():
		ability_key = str(option.get_item_metadata(item_index)).strip_edges()

	_set_draft_loadout_entry(slot_index, ability_key, enabled_check_box.button_pressed)
	_is_loadout_draft_dirty = true
	if _ability_panel_status != null:
		_ability_panel_status.text = "Unsaved changes."
	_refresh_ability_panel_options()


func _on_loadout_enabled_toggled(enabled: bool, slot_index: int) -> void:
	if not _is_loadout_draft_active:
		_begin_loadout_draft()

	var entry: Dictionary = _draft_loadout_entry_for_slot(slot_index)
	var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
	if ability_key == "":
		return

	_set_draft_loadout_entry(slot_index, ability_key, enabled)
	_is_loadout_draft_dirty = true
	if _ability_panel_status != null:
		_ability_panel_status.text = "Unsaved changes."


func _on_cancel_loadout_pressed() -> void:
	_cancel_loadout_draft()
	_ability_panel.visible = false


func _on_inventory_row_input(event: InputEvent, item: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_selected_inventory_item = item.duplicate(true)
	_refresh_inventory_panel()
	_refresh_inventory_comparison()


func _on_panel_drag_handle_input(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_dragged_panel = panel
				_drag_offset = panel.global_position - get_viewport().get_mouse_position()
			elif _dragged_panel == panel:
				_dragged_panel = null


func _move_dragged_panel() -> void:
	if _dragged_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _dragged_panel.size
	var target_position: Vector2 = get_viewport().get_mouse_position() + _drag_offset
	target_position.x = clamp(target_position.x, 0.0, max(viewport_size.x - panel_size.x, 0.0))
	target_position.y = clamp(target_position.y, 0.0, max(viewport_size.y - panel_size.y, 0.0))
	_dragged_panel.global_position = target_position


func _on_combat_toggle_button_pressed() -> void:
	combat_toggle_requested.emit()


func _on_hotbar_slot_pressed(slot_index: int) -> void:
	var entry: Dictionary = _loadout_entry_for_slot(slot_index)
	var ability_name: String = str(entry.get("ability_name", "")).strip_edges()
	if ability_name == "" or not _confirmed_loadout.has(ability_name):
		return

	var current_enabled: bool = bool(_ability_enabled_by_name.get(ability_name, entry.get("enabled", true)))
	ability_toggle_requested.emit(ability_name, not current_enabled)


func _on_weapon_primary_button_pressed() -> void:
	if _weapon_primary_ability_name() == "":
		return

	weapon_primary_requested.emit()


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
	var source_entries: Array = _draft_loadout_entries if _is_loadout_draft_active else _confirmed_loadout_entries
	for entry_variant in source_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var slot_index: int = int(entry.get("slot_index", -1))
		var ability_key: String = str(entry.get("ability_key", "")).strip_edges()
		if ability_key == "":
			continue
		if slot_index < 0 or slot_index >= HOTBAR_SLOT_COUNT:
			_ability_panel_status.text = "Invalid loadout slot."
			return
		if seen_keys.has(ability_key):
			_ability_panel_status.text = "Duplicate abilities are not allowed."
			return

		seen_keys.append(ability_key)
		loadout_entries.append({
			"slot_index": slot_index,
			"ability_key": ability_key,
			"enabled": bool(entry.get("enabled", true)),
		})

	if loadout_entries.size() > HOTBAR_SLOT_COUNT:
		_ability_panel_status.text = "Loadout can contain at most 5 abilities."
		return

	_ability_panel_status.text = "Saving..."
	_is_loadout_save_pending = true
	_pending_loadout_entries = _duplicate_loadout_entries(loadout_entries)
	loadout_save_requested.emit(loadout_entries)


func _on_equipment_option_selected(_item_index: int, _slot_name: String) -> void:
	if _is_refreshing_equipment_ui:
		return

	if _is_equipment_change_pending:
		if _equipment_panel_status != null:
			_equipment_panel_status.text = "Waiting for equipment confirmation."
		_refresh_equipment_slot_options()
		return

	if not _equipment_slot_options.has(_slot_name):
		return

	var option: OptionButton = _equipment_slot_options[_slot_name] as OptionButton
	var selected_index: int = option.selected
	var selected_metadata: Variant = null
	if selected_index >= 0 and selected_index < option.get_item_count():
		selected_metadata = option.get_item_metadata(selected_index)

	var inventory_entry_id: String = _equipment_metadata_inventory_entry_id(selected_metadata)
	var equipment_entries: Array = [{
		"slot": _slot_name,
		"inventory_entry_id": null if selected_metadata == null else inventory_entry_id,
		"item_key": _equipment_metadata_item_key(selected_metadata),
		"unequip": inventory_entry_id == "",
	}]

	_is_equipment_change_pending = true
	if _equipment_panel_status != null:
		_equipment_panel_status.text = "Saving..."
	_refresh_equipment_slot_options()
	equipment_change_requested.emit(equipment_entries)


func _on_message_timer_timeout(timer: SceneTreeTimer) -> void:
	if timer != _message_timer:
		return

	_message_label.text = ""
	_message_label.visible = false
