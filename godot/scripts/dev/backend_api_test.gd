extends Node

@export var base_url: String = "http://127.0.0.1:8000"
@export var email: String = "test@example.com"
@export var password: String = "secret123"
@export var character_name: String = "DevHero"
@export var login_on_ready: bool = false
@export var list_characters_after_login: bool = true

@onready var api_client: BackendApiClient = $BackendApiClient

var _access_token := ""
var _login_request_id := -1


func _ready() -> void:
	api_client.configure(base_url)
	api_client.request_succeeded.connect(_on_request_succeeded)
	api_client.request_failed.connect(_on_request_failed)

	print("Backend API test scene ready.")
	print("Set exported email/password/character_name values in the inspector.")
	print("Call run_login_test(), run_current_user_test(), run_list_characters_test(), or run_create_character_test() from the remote inspector/console.")
	print("Set login_on_ready=true to run login automatically when this scene starts.")

	if login_on_ready:
		run_login_test()


func run_login_test() -> void:
	print("POST /auth/login for %s" % email)
	_login_request_id = api_client.login(email, password)


func run_list_characters_test() -> void:
	if _access_token == "":
		print("No access token yet. Run login first.")
		return

	print("GET /characters")
	api_client.list_characters(_access_token)


func run_current_user_test() -> void:
	if _access_token == "":
		print("No access token yet. Run login first.")
		return

	print("GET /auth/me")
	api_client.get_current_user(_access_token)


func run_create_character_test() -> void:
	if _access_token == "":
		print("No access token yet. Run login first.")
		return

	print("POST /characters name=%s" % character_name)
	api_client.create_character(_access_token, character_name)


func _on_request_succeeded(request_id: int, endpoint: String, data: Variant) -> void:
	print("Backend request succeeded: %s" % endpoint)
	print(data)

	if request_id == _login_request_id and data is Dictionary and data.has("access_token"):
		_access_token = data["access_token"]
		print("Stored access token from login response.")

		if list_characters_after_login:
			run_list_characters_test()


func _on_request_failed(_request_id: int, endpoint: String, status_code: int, message: String) -> void:
	print("Backend request failed: %s status=%s message=%s" % [endpoint, status_code, message])
