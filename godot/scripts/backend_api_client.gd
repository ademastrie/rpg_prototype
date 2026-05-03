extends Node
class_name BackendApiClient

signal request_succeeded(request_id: int, endpoint: String, data: Variant)
signal request_failed(request_id: int, endpoint: String, status_code: int, message: String)

@export var base_url: String = "http://127.0.0.1:8000"

var _http_request: HTTPRequest
var _request_queue: Array[Dictionary] = []
var _active_request: Dictionary = {}
var _next_request_id: int = 1


func _ready() -> void:
	_ensure_http_request()


func configure(new_base_url: String) -> void:
	base_url = _normalize_base_url(new_base_url)


func register(email: String, password: String) -> int:
	return _queue_json_request(
		"/auth/register",
		HTTPClient.METHOD_POST,
		{"email": email, "password": password}
	)


func login(email: String, password: String) -> int:
	return _queue_json_request(
		"/auth/login",
		HTTPClient.METHOD_POST,
		{"email": email, "password": password}
	)


func list_characters(access_token: String) -> int:
	return _queue_json_request(
		"/characters",
		HTTPClient.METHOD_GET,
		{},
		access_token
	)


func create_character(access_token: String, name: String) -> int:
	return _queue_json_request(
		"/characters",
		HTTPClient.METHOD_POST,
		{"name": name},
		access_token
	)


func _queue_json_request(
	endpoint: String,
	method: int,
	payload: Dictionary = {},
	access_token: String = ""
) -> int:
	var request_id := _next_request_id
	_next_request_id += 1

	_request_queue.append({
		"id": request_id,
		"endpoint": endpoint,
		"method": method,
		"payload": payload,
		"access_token": access_token,
	})
	_process_next_request()

	return request_id


func _process_next_request() -> void:
	if not _active_request.is_empty() or _request_queue.is_empty():
		return

	_ensure_http_request()
	_active_request = _request_queue.pop_front()

	var endpoint: String = _active_request["endpoint"]
	var method: int = _active_request["method"]
	var payload: Dictionary = _active_request["payload"]
	var access_token: String = _active_request["access_token"]
	var body := ""
	var headers := PackedStringArray(["Content-Type: application/json"])

	if access_token != "":
		headers.append("Authorization: Bearer %s" % access_token)

	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var error := _http_request.request(_build_url(endpoint), headers, method, body)
	if error != OK:
		var failed_request := _active_request
		_active_request = {}
		request_failed.emit(
			failed_request["id"],
			failed_request["endpoint"],
			0,
			"Failed to start HTTP request: %s" % error
		)
		_process_next_request()


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var completed_request := _active_request
	_active_request = {}

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(
			completed_request["id"],
			completed_request["endpoint"],
			response_code,
			"HTTP request failed with result code %s." % result
		)
		_process_next_request()
		return

	var response_text := body.get_string_from_utf8()
	var parsed_response: Variant = null

	if response_text != "":
		var json := JSON.new()
		var parse_error := json.parse(response_text)
		if parse_error != OK:
			request_failed.emit(
				completed_request["id"],
				completed_request["endpoint"],
				response_code,
				"Failed to parse JSON response."
			)
			_process_next_request()
			return
		parsed_response = json.data

	if response_code < 200 or response_code >= 300:
		request_failed.emit(
			completed_request["id"],
			completed_request["endpoint"],
			response_code,
			_get_error_message(parsed_response)
		)
		_process_next_request()
		return

	request_succeeded.emit(
		completed_request["id"],
		completed_request["endpoint"],
		parsed_response
	)
	_process_next_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return

	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)


func _build_url(endpoint: String) -> String:
	return "%s%s" % [_normalize_base_url(base_url), endpoint]


func _normalize_base_url(value: String) -> String:
	var normalized := value.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _get_error_message(data: Variant) -> String:
	if data is Dictionary and data.has("detail"):
		return str(data["detail"])
	return "Backend request failed."
