extends Control

@export var base_url: String = "http://127.0.0.1:8000"

@onready var api_client: BackendApiClient = $BackendApiClient
@onready var email_edit: LineEdit = %EmailEdit
@onready var password_edit: LineEdit = %PasswordEdit
@onready var status_label: Label = %StatusLabel
@onready var character_list: ItemList = %CharacterList
@onready var character_name_edit: LineEdit = %CharacterNameEdit
@onready var starter_ability_option: OptionButton = %StarterAbilityOption

var _access_token := ""
var _characters: Array[Dictionary] = []
var _pending_requests: Dictionary = {}


func _ready() -> void:
	api_client.configure(base_url)
	api_client.request_succeeded.connect(_on_request_succeeded)
	api_client.request_failed.connect(_on_request_failed)

	%RegisterButton.pressed.connect(_on_register_pressed)
	%LoginButton.pressed.connect(_on_login_pressed)
	%CreateCharacterButton.pressed.connect(_on_create_character_pressed)
	%RefreshCharactersButton.pressed.connect(_on_refresh_characters_pressed)
	%EnterGameButton.pressed.connect(_on_enter_game_pressed)
	character_list.item_selected.connect(_on_character_selected)

	_setup_starter_ability_options()
	_set_status("Enter an email and password, then register or log in.")


func _on_register_pressed() -> void:
	var email := email_edit.text.strip_edges()
	var password := password_edit.text
	if email == "" or password == "":
		_set_status("Email and password are required.")
		return

	_track_request(api_client.register(email, password), "register")
	_set_status("Registering account...")


func _on_login_pressed() -> void:
	var email := email_edit.text.strip_edges()
	var password := password_edit.text
	if email == "" or password == "":
		_set_status("Email and password are required.")
		return

	_track_request(api_client.login(email, password), "login")
	_set_status("Logging in...")


func _on_create_character_pressed() -> void:
	if not _has_token():
		return

	var character_name := character_name_edit.text.strip_edges()
	if character_name == "":
		_set_status("Character name is required.")
		return

	var starter_ability_key := _selected_starter_ability_key()
	_track_request(api_client.create_character(_access_token, character_name, starter_ability_key), "create_character")
	_set_status("Creating character...")


func _on_refresh_characters_pressed() -> void:
	if not _has_token():
		return

	_refresh_characters()


func _on_enter_game_pressed() -> void:
	var selected_items := character_list.get_selected_items()
	if selected_items.is_empty():
		_set_status("Select a character before entering the game.")
		return

	var selected_index := selected_items[0]
	if selected_index < 0 or selected_index >= _characters.size():
		_set_status("Select a valid character before entering the game.")
		return

	ClientSession.access_token = _access_token
	ClientSession.selected_character = _characters[selected_index]

	var error := get_tree().change_scene_to_file("res://scenes/client/client_game.tscn")
	if error != OK:
		_set_status("Failed to enter game: %s" % error)


func _on_character_selected(index: int) -> void:
	if index >= 0 and index < _characters.size():
		var character := _characters[index]
		_set_status("Selected %s." % character.get("name", "character"))


func _on_request_succeeded(request_id: int, _endpoint: String, data: Variant) -> void:
	var action: String = _pending_requests.get(request_id, "")
	_pending_requests.erase(request_id)

	match action:
		"register":
			_set_status("Account created. Log in to continue.")
		"login":
			if data is Dictionary and data.has("access_token"):
				_access_token = data["access_token"]
				ClientSession.access_token = _access_token
				_set_status("Logged in. Loading account...")
				_track_request(api_client.get_current_user(_access_token), "current_user")
			else:
				_set_status("Login response did not include an access token.")
		"current_user":
			if not (data is Dictionary):
				_set_status("Logged in. Loading characters...")
			else:
				ClientSession.current_user = data
				if data.has("email"):
					_set_status("Logged in as %s. Loading characters..." % data["email"])
				else:
					_set_status("Logged in. Loading characters...")
			_refresh_characters()
		"list_characters":
			_show_characters(data)
			_set_status("Characters loaded.")
		"create_character":
			character_name_edit.text = ""
			_set_status("Character created. Refreshing list...")
			_refresh_characters()
		_:
			_set_status("Request succeeded.")


func _on_request_failed(request_id: int, _endpoint: String, status_code: int, message: String) -> void:
	_pending_requests.erase(request_id)
	_set_status("Request failed (%s): %s" % [status_code, message])


func _refresh_characters() -> void:
	_track_request(api_client.list_characters(_access_token), "list_characters")
	_set_status("Loading characters...")


func _show_characters(data: Variant) -> void:
	character_list.clear()
	_characters.clear()
	ClientSession.selected_character = {}

	if not (data is Array):
		_set_status("Character response was not a list.")
		return

	for character in data:
		if not (character is Dictionary):
			continue

		var character_name: String = str(character.get("name", "Unnamed"))
		var level: int = int(character.get("level", 1))
		var region_id: String = str(character.get("region_id", "unknown_region"))
		_characters.append(character)
		character_list.add_item("%s - Level %s - %s" % [character_name, level, region_id])

	if character_list.item_count == 0:
		character_list.add_item("No characters yet.")


func _setup_starter_ability_options() -> void:
	starter_ability_option.clear()
	starter_ability_option.add_item("Slash")
	starter_ability_option.set_item_metadata(0, "slash")
	starter_ability_option.add_item("Firebolt")
	starter_ability_option.set_item_metadata(1, "firebolt")
	starter_ability_option.select(0)


func _selected_starter_ability_key() -> String:
	var selected_index := starter_ability_option.selected
	if selected_index < 0:
		return "slash"

	return str(starter_ability_option.get_item_metadata(selected_index))


func _track_request(request_id: int, action: String) -> void:
	_pending_requests[request_id] = action


func _has_token() -> bool:
	if _access_token == "":
		_set_status("Log in first.")
		return false
	return true


func _set_status(message: String) -> void:
	status_label.text = message
