extends Node2D

@onready var inventory_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var room_container: Node2D = $RoomContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var help_button: TextureButton = $UI/Help
@onready var exit_button: Button = $UI/ExitButton
@onready var help_overlay: Sprite2D = $UI/HelpOverlay
@onready var message_label: Label = $UI/HelpOverlay/MessageLabel
@onready var yes_button: Button = $UI/HelpOverlay/HelpContent/YesButton
@onready var no_button: Button = $UI/HelpOverlay/HelpContent/NoButton
@onready var help_image: Sprite2D = $UI/HelpOverlay/HelpImage
@onready var ok_button: Button = $UI/HelpOverlay/HelpContent/OKButton
@onready var music_player = $SoundPool/MusicPlayer
@onready var ambient_player = $SoundPool/AmbientPlayer
@onready var click_player = $SoundPool/ClickPlayer
@onready var done_player = $SoundPool/DonePlayer
@onready var take_player = $SoundPool/TakePlayer
@onready var woosh_player = $SoundPool/WooshPlayer
@onready var wrong_player = $SoundPool/WrongPlayer
@onready var success_player = $SoundPool/SuccessPlayer

# Definisci la mappa stanza → scena speciale
const SPECIAL_ROOMS = {
	"l05telescope": preload("res://scenes/telescope_luig.tscn"),
	"p05telescope": preload("res://scenes/telescope_pog.tscn")
}
var special_instance: Node = null

var current_room: Node = null
var sparkle_timer: Timer = null
var current_help_image: String = ""
var overlay_mode: String = ""
var puzzle_check_timer: Timer = null

# Inventory drag system
var dragged_inventory_key: String = ""
var dragged_inventory_original: TextureButton = null
var drag_ghost: Sprite2D = null
var is_dragging: bool = false

# Sposta drag system
var dragged_sposta: InteractiveObject = null
var drag_sposta_active: bool = false
var drag_sposta_start_pos: Vector2 = Vector2.ZERO

# Cutscene
var is_cutscene: bool = false
var is_walking_cutscene: bool = false
var walking_npc: Node = null
var walk_velocity: Vector2 = Vector2.ZERO
var walk_timer: Timer = null

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	room_container.position = viewport_size / 2

	GameState.reset_level_state()
	load_level_data()
	setup_ui()
	load_room("001")
	setup_sparkle_system()
	setup_help_system()

	puzzle_check_timer = Timer.new()
	puzzle_check_timer.one_shot = true
	puzzle_check_timer.wait_time = 1.0
	puzzle_check_timer.timeout.connect(_check_puzzle_completion)
	add_child(puzzle_check_timer)

func _save_current_puzzle_state() -> void:
	if not current_room:
		return
	var puzzles = _get_all_puzzle_objects()
	var indices = []
	for puzzle in puzzles:
		indices.append(puzzle.puzzle_index)
	GameState.save_puzzle_state(current_room.room_key, indices)

func _update_inventory_display() -> void:
	for child in inventory_container.get_children():
		child.queue_free()
	for item_key in GameState.inventory_items:
		var inv_item = preload("res://scenes/InventoryItem.tscn").instantiate()
		inv_item.item_key = item_key
		var texture = JSONLoader.get_level_texture(GameState.current_level, item_key + ".png")
		if not texture:
			texture = JSONLoader.get_level_texture(GameState.current_level, item_key)
		if texture:
			inv_item.texture_normal = texture
		inventory_container.add_child(inv_item)
		inv_item.drag_started.connect(_on_inventory_drag_started)

func _on_inventory_drag_started(item_key: String, button: TextureButton) -> void:
	if is_dragging:
		end_drag()
	dragged_inventory_key = item_key
	dragged_inventory_original = button
	is_dragging = true

	drag_ghost = Sprite2D.new()
	drag_ghost.texture = button.texture_normal
	drag_ghost.z_index = 99
	add_child(drag_ghost)
	drag_ghost.global_position = get_global_mouse_position()

	button.visible = false

func _process(delta: float) -> void:
	if is_dragging and drag_ghost:
		drag_ghost.global_position = get_global_mouse_position()
	
	if drag_sposta_active and dragged_sposta:
		dragged_sposta.global_position = get_global_mouse_position()
	
	if is_walking_cutscene and walking_npc:
		walking_npc.global_position += walk_velocity * delta

func _input(event: InputEvent) -> void:
	if is_cutscene:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if drag_sposta_active:
			end_drag_sposta()
		elif is_dragging:
			end_drag()

func start_drag_sposta(obj: InteractiveObject) -> void:
	if drag_sposta_active or is_dragging:
		return
	drag_sposta_active = true
	dragged_sposta = obj
	drag_sposta_start_pos = obj.global_position
	obj.z_index +=9
	_disable_all_interactive(true)

func end_drag_sposta() -> void:
	if not drag_sposta_active or not dragged_sposta:
		_cleanup_sposta_drag()
		return
	
	var obj = dragged_sposta
	var start_pos = drag_sposta_start_pos
	var tween = create_tween()
	tween.tween_property(obj, "global_position", start_pos, 0.2).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(obj):
		obj.global_position = start_pos
	
	_cleanup_sposta_drag()

func _cleanup_sposta_drag() -> void:
	if dragged_sposta:
		dragged_sposta.z_index -=9
	dragged_sposta = null
	drag_sposta_active = false
	_disable_all_interactive(false)

func _disable_all_interactive(disable: bool) -> void:
	if not current_room:
		return
	var all = _find_all_interactive_objects(current_room)
	for obj in all:
		if obj is InteractiveObject:
			obj.monitoring = not disable
			obj.monitorable = not disable

func end_drag() -> void:
	if not is_dragging:
		return

	var target_metti = _find_metti_at_mouse()
	if target_metti:
		var accepted = target_metti.item_name.split(",")
		var accepted_items = []
		for a in accepted:
			accepted_items.append(a.strip_edges())
		if dragged_inventory_key in accepted_items:
			_use_item_on_metti(dragged_inventory_key, target_metti.target_room)
			GameState.inventory_items.erase(dragged_inventory_key)
			dragged_inventory_original.queue_free()
			_update_inventory_display()
			_cleanup_drag()
			return

	# Not used: show original button
	wrong_player.play()
	if dragged_inventory_original:
		dragged_inventory_original.visible = true
	_cleanup_drag()

func _find_metti_at_mouse() -> InteractiveObject:
	var mouse_pos = get_global_mouse_position()
	if current_room:
		var all_objects = _find_all_interactive_objects(current_room)
		for obj in all_objects:
			if obj is InteractiveObject and obj.object_type == "metti":
				if _is_point_in_sprite(obj, mouse_pos):
					return obj
	return null

func _is_point_in_sprite(obj: InteractiveObject, point: Vector2) -> bool:
	var sprite = obj.get_node("Sprite2D") as Sprite2D
	if not sprite or not sprite.texture:
		return false
	var tex_size = sprite.texture.get_size()
	var center = sprite.global_position
	var rect = Rect2(center - tex_size / 2, tex_size)
	return rect.has_point(point)

func _use_item_on_metti(item_key: String, target_room: String) -> void:
	GameState.mark_item_as_used(item_key)
	if current_room:
		GameState.replaced_rooms[current_room.room_key] = target_room
	done_player.play()
	load_room(target_room)

func _cleanup_drag() -> void:
	if drag_ghost:
		drag_ghost.queue_free()
		drag_ghost = null
	dragged_inventory_key = ""
	dragged_inventory_original = null
	is_dragging = false

func setup_help_system() -> void:
	help_button.visible = false
	help_button.pressed.connect(_on_help_button_pressed)
	help_overlay.visible = false
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	help_image.visible = false
	ok_button.visible = false

func _on_exit_button_pressed() -> void:
	overlay_mode = "exit"
	exit_button.visible = false
	help_button.visible = false
	_play_woosh_sounds()
	_destroy_room_timers()
	help_overlay.visible = true
	message_label.text = "exit?"
	message_label.visible = true
	yes_button.visible = true
	no_button.visible = true
	help_image.visible = false
	ok_button.visible = false
	room_container.visible = false

func _on_help_button_pressed() -> void:
	overlay_mode = "help"
	help_overlay.visible = true
	help_button.visible = false
	exit_button.visible = false
	message_label.text = "Need a little HELP?"
	message_label.visible = true
	yes_button.visible = true
	no_button.visible = true
	help_image.visible = false
	ok_button.visible = false
	_play_woosh_sounds()
	_destroy_room_timers()
	room_container.visible = false

func _on_yes_pressed() -> void:
	_play_woosh_sounds()
	match overlay_mode:
		"help":
			message_label.visible = false
			yes_button.visible = false
			no_button.visible = false
			if current_help_image != "":
				var texture = JSONLoader.get_level_texture(GameState.current_level, current_help_image)
				if texture:
					help_image.texture = texture
					help_image.visible = true
			ok_button.visible = true
		"exit":
			GameState.inventory_items.clear()
			CouchGames.gameplay_end()
			get_tree().change_scene_to_file("res://scenes/LevelSelectScene.tscn")

func _on_no_pressed() -> void:
	_play_woosh_sounds()
	help_overlay.visible = false
	exit_button.visible = true
	if current_help_image != "":
		help_button.visible = true
	overlay_mode = ""
	room_container.visible = true
	if current_room:
		load_room(current_room.room_key)

func _on_ok_pressed() -> void:
	_play_woosh_sounds()
	help_overlay.visible = false
	if current_help_image != "":
		help_button.visible = true
	overlay_mode = ""
	exit_button.visible = true
	room_container.visible = true
	if current_room:
		load_room(current_room.room_key)

func _destroy_room_timers() -> void:
	if not current_room:
		return
	var timers = current_room.find_children("*", "Timer", true, false)
	for timer in timers:
		if timer is Timer:
			timer.stop()
			timer.queue_free()

func setup_sparkle_system() -> void:
	sparkle_timer = Timer.new()
	sparkle_timer.wait_time = 5.0
	sparkle_timer.autostart = true
	sparkle_timer.timeout.connect(_on_sparkle_timer_timeout)
	add_child(sparkle_timer)

func _on_sparkle_timer_timeout() -> void:
	if not current_room:
		return
	var interactive_objects = _find_all_interactive_objects(current_room)
	if interactive_objects.is_empty():
		return
	var target = interactive_objects[randi() % interactive_objects.size()]
	var base_pos = target.global_position + Vector2(0, -9)
	var sparkle_instance = preload("res://scenes/Sparkle.tscn").instantiate()
	ui_layer.add_child(sparkle_instance)
	sparkle_instance.appear_at(base_pos)

func _find_all_interactive_objects(node: Node) -> Array:
	var objects = []
	if node is Area2D and node.has_method("setup"):
		var is_being_removed = node.get("is_being_removed")
		if not is_being_removed or is_being_removed == false:
			objects.append(node)
	for child in node.get_children():
		objects.append_array(_find_all_interactive_objects(child))
	return objects

func load_level_data() -> void:
	var data = JSONLoader.load_level(GameState.current_level)
	if data.is_empty():
		printerr("Failed to load level data")
		return
	GameState.rooms_data = data
	if data.has("config"):
		GameState.set_level_config(data.config)

func setup_ui() -> void:
	exit_button.pressed.connect(_on_exit_button_pressed)

func load_room(room_key: String) -> void:
	ambient_player.pitch_scale = randf_range(0.9, 1.1)
	ambient_player.play()

	# Reset cutscene
	is_cutscene = false
	is_walking_cutscene = false
	walk_velocity = Vector2.ZERO
	walking_npc = null
	if walk_timer:
		walk_timer.stop()
		walk_timer.queue_free()
		walk_timer = null

	if sparkle_timer:
		sparkle_timer.stop()
	if puzzle_check_timer:
		puzzle_check_timer.stop()

	var actual_key = room_key
	while actual_key in GameState.replaced_rooms:
		actual_key = GameState.replaced_rooms[actual_key]

	if actual_key == "end": # finale
		GameState.inventory_items.clear() # pulisce l'inventario
		get_tree().change_scene_to_file("res://scenes/EndScene.tscn")
		return   # exit the function immediately

	if current_room:
		current_room.queue_free()
		current_room = null

	if not GameState.rooms_data.has("stanze"):
		printerr("No 'stanze' key in level data")
		return
	if not GameState.rooms_data.stanze.has(actual_key):
		printerr("Room not found: ", actual_key)
		return

	if sparkle_timer:
		sparkle_timer.start()
	
	# SPECIALROOM Rimuovi eventuale istanza precedente
	if special_instance:
		special_instance.queue_free()
		special_instance = null

	# Se la stanza corrente è una di quelle speciali, istanzia la scena corrispondente
	if actual_key in SPECIAL_ROOMS:
		var scene = SPECIAL_ROOMS[actual_key]
		special_instance = scene.instantiate()
		room_container.add_child(special_instance)
		special_instance.z_index = 0  # sotto a tutto
		special_instance.position = Vector2.ZERO

	var room_scene = preload("res://scenes/Room.tscn")
	current_room = room_scene.instantiate()
	room_container.add_child(current_room)

	var room_data = GameState.rooms_data.stanze[actual_key].duplicate(true)

	# Filter objects
	if room_data.has("oggetti"):
		var oggetti = room_data.oggetti
		var filtered_oggetti = []
		for oggetto in oggetti:
			if oggetto.get("tipo") == "prendi":
				var item_id = oggetto.get("item")
				if item_id:
					var item_key = item_id.replace(".png", "")
					if GameState.used_items.has(item_key) or item_key in GameState.inventory_items:
						continue
			filtered_oggetti.append(oggetto)
		room_data.oggetti = filtered_oggetti

	current_room.initialize(room_data, actual_key)
	_update_inventory_display()

	if room_data.has("help"):
		current_help_image = room_data["help"]
		help_button.visible = true
	else:
		current_help_image = ""
		help_button.visible = false

	if room_data.has("suono"):
		_play_named_sound(room_data["suono"])

func handle_object_interaction(obj: Node) -> void:
	if is_cutscene:
		return
	click_player.pitch_scale = randf_range(0.95, 1.05)
	click_player.play()

	match obj.object_type:
		"porta":
			if obj.item_name == "walk":
				handle_walking_door(obj)
			else:
				load_room(obj.target_room)
		"prendi":
			collect_to_inventory(obj)
			take_player.play()
		"metti":
			wrong_player.play()
		"puzzle":
			handle_puzzle_interaction(obj)
		"sposta":
			start_drag_sposta(obj)

func handle_walking_door(door: InteractiveObject) -> void:
	if is_cutscene or is_walking_cutscene:
		return
	is_cutscene = true
	is_walking_cutscene = true

	if is_dragging:
		end_drag()
	if sparkle_timer:
		sparkle_timer.stop()

	var all_objects = _find_all_interactive_objects(current_room)
	for obj in all_objects:
		obj.monitoring = false
		obj.monitorable = false

	var npc = _find_npc()
	if not npc:
		load_room(door.target_room)
		is_cutscene = false
		is_walking_cutscene = false
		return

	var door_pos = door.global_position
	var target_pos = door_pos + Vector2(0, -75)
	var direction = (target_pos - npc.global_position).normalized()
	npc.flip_h = target_pos.x < npc.global_position.x
	npc.start_walking()
	walk_velocity = direction * 150
	walking_npc = npc

	walk_timer = Timer.new()
	walk_timer.wait_time = 0.5
	walk_timer.one_shot = true
	walk_timer.timeout.connect(_on_walk_finished.bind(door.target_room))
	add_child(walk_timer)
	walk_timer.start()

func _on_walk_finished(target_room: String) -> void:
	if walking_npc and walking_npc.has_method("stop_walking"):
		walking_npc.stop_walking()
	walk_velocity = Vector2.ZERO
	walking_npc = null
	if walk_timer:
		walk_timer.queue_free()
		walk_timer = null
	load_room(target_room)
	is_cutscene = false
	is_walking_cutscene = false

func _find_npc() -> Node:
	if not current_room:
		return null
	var nodes = current_room.find_children("*", "NPC", true, false)
	return nodes[0] if nodes.size() > 0 else null

func collect_to_inventory(obj: InteractiveObject) -> void:
	var item_key = obj.item_name
	var temp_sprite = Sprite2D.new()
	temp_sprite.texture = obj.sprite.texture
	temp_sprite.centered = true
	temp_sprite.global_position = obj.global_position
	temp_sprite.z_index = 98
	add_child(temp_sprite)
	obj.queue_free()
	var target_pos = inventory_container.global_position + inventory_container.size / 2
	var tween = create_tween()
	tween.tween_property(temp_sprite, "global_position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
	await tween.finished
	GameState.inventory_items.append(item_key)
	_update_inventory_display()
	temp_sprite.queue_free()

func handle_puzzle_interaction(obj: Node) -> void:
	if obj.has_method("cycle_puzzle"):
		obj.cycle_puzzle()
		_save_current_puzzle_state()
	puzzle_check_timer.stop()
	puzzle_check_timer.start()

func _check_puzzle_completion() -> void:
	var all_puzzles = _get_all_puzzle_objects()
	var all_correct = true
	var target_room = ""
	for puzzle in all_puzzles:
		if not puzzle.is_puzzle_correct():
			all_correct = false
			break
		if target_room == "" and puzzle.has_method("get_puzzle_target"):
			target_room = puzzle.get_puzzle_target()
	if all_correct and target_room != "":
		if current_room:
			GameState.replaced_rooms[current_room.room_key] = target_room
		done_player.play()
		load_room(target_room)

func _get_all_puzzle_objects() -> Array:
	var result = []
	if not current_room:
		return result
	var all_interactive = _find_all_interactive_objects(current_room)
	for obj in all_interactive:
		if obj is InteractiveObject and obj.object_type == "puzzle":
			result.append(obj)
	return result

func _play_woosh_sounds() -> void:
	click_player.pitch_scale = randf_range(0.95, 1.05)
	click_player.play()
	woosh_player.pitch_scale = randf_range(0.95, 1.05)
	woosh_player.play()

func _play_named_sound(sound_name: String) -> void:
	match sound_name:
		"music":
			music_player.play()
		"success":
			success_player.play()
		"done":
			done_player.pitch_scale = randf_range(0.95, 1.05)
			done_player.play()
		"woosh":
			woosh_player.pitch_scale = randf_range(0.95, 1.05)
			woosh_player.play()
