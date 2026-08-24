extends Node

signal remote_message_received(type: String, payload: Dictionary)

func send_message(type: String, payload: Dictionary) -> void:
	# Placeholder for debug
	print("SEND (placeholder): ", type, " ", payload)

func _ready() -> void:
	# Placeholder: simulate a connection
	print("CouchMultiplayer initialized (placeholder)")
