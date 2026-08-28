extends Node

signal remote_message_received(type: String, payload: Dictionary)

const MAX_QUEUED_MESSAGES := 32

var _is_ready := false
var _queued_messages: Array[Dictionary] = []


func send_message(type: String, payload: Dictionary) -> void:
	if type.is_empty():
		push_warning("CouchMultiplayer: refusing to send a message with an empty type")
		return

	# A player can interact while CouchGames.init() is still waiting for the
	# parent-page bridge. Preserve those early actions and flush them in order
	# once the authenticated lobby transport is ready.
	if not _is_ready:
		if _queued_messages.size() >= MAX_QUEUED_MESSAGES:
			push_warning("CouchMultiplayer: startup queue is full; dropping '%s'" % type)
			return
		_queued_messages.append({
			"type": type,
			"payload": payload.duplicate(true),
		})
		return

	_send_now(type, payload)


func _ready() -> void:
	# CouchGames owns the platform's authenticated lobby WebSocket. Lobby events
	# are its supported low-frequency gameplay-message channel; /ws/signaling is
	# reserved for WebRTC SDP/ICE negotiation and must not be opened directly.
	await CouchGames.init()

	if not CouchGames.lobby.event_received.is_connected(_on_lobby_event):
		CouchGames.lobby.event_received.connect(_on_lobby_event)

	_is_ready = true
	_flush_queued_messages()

	if CouchGames.lobby.is_available:
		print("CouchMultiplayer connected to the Couch Games lobby transport")
	else:
		push_warning("CouchMultiplayer: no active Couch Games lobby; messages will be dropped")


func _send_now(type: String, payload: Dictionary) -> void:
	if not CouchGames.lobby.is_available:
		push_warning("CouchMultiplayer: no active lobby; dropping '%s'" % type)
		return
	CouchGames.lobby.send_event(type, payload)


func _flush_queued_messages() -> void:
	var pending := _queued_messages
	_queued_messages = []
	for message in pending:
		_send_now(str(message["type"]), message["payload"])


func _on_lobby_event(type: String, data: Variant, _sender_user_id: String) -> void:
	if not data is Dictionary:
		push_warning("CouchMultiplayer: ignoring '%s' with a non-dictionary payload" % type)
		return
	remote_message_received.emit(type, data as Dictionary)
