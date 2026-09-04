extends Node

var inventory_items: Array = []        # list of item keys

# === CURRENT LEVEL ===
var current_level: String = ""

# === LEVEL DATA ===
var rooms_data: Dictionary = {}
var replaced_rooms: Dictionary = {}
var collected_bonuses: Array = []
var used_items: Dictionary = {}
var particle_played: Dictionary = {}   # key: room_key, value: bool
var puzzle_states: Dictionary = {}
# === CONFIG ===
var color_bg : Color = Color("e1ba69ff") # rosa e9d4cf
var color_fg : Color = Color("fcceacff")
var win_bonus_count: int = 5

# === PROGRESS ===
var level_progress: Dictionary = {}

func _ready() -> void:
	load_progress()
	CouchGames.init()

func mark_item_as_used(item_key: String) -> void:
	used_items[item_key] = true

func save_puzzle_state(room_key: String, indices: Array) -> void:
	puzzle_states[room_key] = indices

func get_puzzle_state(room_key: String) -> Array:
	return puzzle_states.get(room_key, [])

func reset_level_state() -> void:
	replaced_rooms.clear()
	collected_bonuses.clear()
	used_items.clear()
	particle_played.clear()
	puzzle_states.clear()

func set_level_config(config: Dictionary) -> void:
	if config.has("win_bonus_count"):
		win_bonus_count = config.win_bonus_count

func save_level_progress(level_name: String, bonus_count: int) -> void:
	level_progress[level_name] = bonus_count
	save_to_file()

func get_level_progress(level_name: String) -> int:
	var progress = level_progress.get(level_name, 0)
	return progress

func load_progress() -> void:
	# Carica i progressi dal file
	var file_path = "user://progress.save"
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = file.get_var()
			if typeof(data) == TYPE_DICTIONARY:
				level_progress = data
			else:
				print("Invalid save data format")
			file.close()
	else:
		print("No save file found, starting fresh")
		level_progress = {}

func save_to_file() -> void:
	var file = FileAccess.open("user://progress.save", FileAccess.WRITE)
	if file:
		file.store_var(level_progress)
		file.close()

func get_all_level_progress() -> Dictionary:
	return level_progress
