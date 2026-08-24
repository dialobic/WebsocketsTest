extends Node2D

@onready var bg_sprite: Sprite2D = $Background
@onready var objects_container: Node2D = $Objects

const NPC_SCENE = preload("res://scenes/NPC.tscn")
const PARTICLE_SCENE = preload("res://scenes/particles.tscn")
const PARTICLE2_SCENE = preload("res://scenes/particles2.tscn")

var room_key: String
var room_timer: Timer = null

func initialize(data: Dictionary, key: String) -> void:
	room_key = key
	
	# Carica background
	var bg_texture = JSONLoader.get_level_texture(GameState.current_level, data.get("image", ""))
	if bg_texture:
		bg_sprite.texture = bg_texture
		bg_sprite.centered = true
		bg_sprite.position = Vector2.ZERO
	
	# Crea oggetti
	_create_objects(data.get("oggetti", []))
	_restore_puzzle_state()
	
func _restore_puzzle_state() -> void:
	var saved_indices = GameState.get_puzzle_state(room_key)
	if saved_indices.is_empty():
		return
	# Collect puzzle objects in creation order
	var puzzle_objects = []
	for child in objects_container.get_children():
		if child is InteractiveObject and child.object_type == "puzzle":
			puzzle_objects.append(child)
	for i in range(min(puzzle_objects.size(), saved_indices.size())):
		puzzle_objects[i].set_puzzle_index(saved_indices[i])

func _create_objects(objects_data: Array) -> void:
	var interactive_scene = preload("res://scenes/InteractiveObject.tscn")
	var order = 0 # per lo z_index
	
	for obj_data in objects_data:
		var tipo = obj_data.get("tipo")
		
		if tipo == "npc":
			_create_npc_object(obj_data, order)
		elif tipo == "timer":
			_create_timer(obj_data)
		elif tipo == "cambio":
			_handle_cambio(obj_data)
		elif tipo == "deco":
			_create_deco_object(obj_data, order)
		elif tipo == "parts":
			_create_particle(obj_data)
		elif tipo == "parts2":
			_create_particle2(obj_data)
		else:
			_create_interactive_object(obj_data, interactive_scene, order)
		
		order += 1

func _create_particle(data: Dictionary) -> void:
	if GameState.particle_played.get(room_key, false):
		return
	
	var particle = PARTICLE_SCENE.instantiate()
	objects_container.add_child(particle)
	
	# Position
	var pos = data.get("pos", [0, 0])
	particle.position = Vector2(pos[0], pos[1])
	
	# Start emitting
	particle.emitting = true
	
	# Play sound if specified in "item" field
	var sound = data.get("item", "")
	if sound != "":
		var game_scene = get_parent().get_parent()
		if game_scene and game_scene.has_method("_play_named_sound"):
			game_scene._play_named_sound(sound)
	
	# Mark as played
	GameState.particle_played[room_key] = true

func _create_particle2(data: Dictionary) -> void:
	var particle = PARTICLE2_SCENE.instantiate()
	objects_container.add_child(particle)
	
	# Position
	var pos = data.get("pos", [0, 0])
	particle.position = Vector2(pos[0], pos[1])
	
	# Start emitting
	particle.emitting = true
	
	# Auto‑remove after finish
	if particle.one_shot:
		particle.finished.connect(particle.queue_free)

func _create_deco_object(data: Dictionary, order: int) -> void:
	var deco
	var textures_str = data.get("item", "")
	if textures_str != "" and "," in textures_str:
		# Animated deco
		deco = AnimatedSprite2D.new()
		var frames = SpriteFrames.new()
		var texture_names = textures_str.split(",")
		for i in range(texture_names.size()):
			var tex_name = texture_names[i].strip_edges()
			var texture = JSONLoader.get_level_texture(GameState.current_level, tex_name)
			if texture:
				frames.add_frame("default", texture)
		if frames.get_frame_count("default") > 0:
			frames.set_animation_speed("default", 1.0 / 0.5)  # 3.333 FPS = 0.3 sec per frame
			deco.sprite_frames = frames
			deco.animation = "default"
			deco.play()
			# Random start frame to break sync
			deco.frame = randi() % deco.sprite_frames.get_frame_count("default")
		else:
			# Fallback to static sprite if no valid textures
			deco = Sprite2D.new()
			var icon = data.get("icona", "")
			if icon != "":
				var texture = JSONLoader.get_level_texture(GameState.current_level, icon)
				if texture:
					deco.texture = texture
	else:
		# Static deco
		deco = Sprite2D.new()
		var icon = data.get("icona", "")
		if icon != "":
			var texture = JSONLoader.get_level_texture(GameState.current_level, icon)
			if texture:
				deco.texture = texture
	
	objects_container.add_child(deco)
	deco.z_index = order
	var pos = data.get("pos", [0, 0])
	deco.position = Vector2(pos[0], pos[1])
	deco.centered = true   # For Sprite2D, for AnimatedSprite2D it's also valid

func _handle_cambio(data: Dictionary) -> void:
	var target = data.get("target", "")
	if target == "":
		return
	
	# Controlla se la stanza target non è già stata sostituita con la stanza corrente
	if GameState.replaced_rooms.has(target) and GameState.replaced_rooms[target] == room_key:
		# Già sostituita, non fare nulla
		return
	
	# Altrimenti, imposta che la stanza target viene sostituita con quella corrente
	GameState.replaced_rooms[target] = room_key

func _create_npc_object(data: Dictionary, order: int) -> void:
	var npc = NPC_SCENE.instantiate()
	objects_container.add_child(npc)
	
	var pos = data.get("pos", [0, 0])
	npc.position = Vector2(pos[0], pos[1])
	npc.z_index = order
	
	var icon = data.get("icona", "")
	if icon != "":
		var texture = JSONLoader.get_level_texture(GameState.current_level, icon)
		if texture:
			npc.texture = texture
	
	var walk_str = data.get("item", "")
	if walk_str != "":
		var frames = walk_str.split(",")
		for i in range(frames.size()):
			frames[i] = frames[i].strip_edges()
		npc.setup_walk(frames)

func _create_timer(data: Dictionary) -> void:
	var duration_str = data.get("item", "1000")
	var duration = duration_str.to_float() / 1000.0
	var target = data.get("target", "")
	if target == "":
		return
	
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout.bind(target))
	add_child(timer)
	timer.start()
	room_timer = timer

func _on_timer_timeout(target: String) -> void:
	var game_scene = get_parent().get_parent()
	if game_scene and game_scene.has_method("load_room"):
		game_scene.load_room(target)

func _create_interactive_object(data: Dictionary, scene: PackedScene, order: int) -> void:
	var interactive_obj = scene.instantiate()
	objects_container.add_child(interactive_obj)
	interactive_obj.z_index = order
	interactive_obj.setup(data)
	
	interactive_obj.object_clicked.connect(_on_interactive_object_clicked)

func _on_interactive_object_clicked(obj: Node) -> void:
	var game_scene = get_parent().get_parent()
	if game_scene and game_scene.has_method("handle_object_interaction"):
		game_scene.handle_object_interaction(obj)

# Metodi per pausa timer (opzionali) ... cancellarli?
func pause_timer() -> void:
	if room_timer and not room_timer.is_stopped():
		room_timer.paused = true

func resume_timer() -> void:
	if room_timer and room_timer.paused:
		room_timer.paused = false
