class_name InteractiveObject
extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
const PUFF_SCENE = preload("res://scenes/Puff.tscn")

var object_type: String = ""
var target_room: String = ""
var item_name: String = ""
var is_being_removed: bool = false

enum ObjectType {DOOR, COLLECTABLE, PLACEABLE, BONUS, PUZZLE, SPOSTA}

var puzzle_icons: Array = []
var puzzle_index: int = 0
var puzzle_target: String = ""
var last_click_time: int = 0

# sposta
var original_home_pos: Vector2 = Vector2.ZERO

# swap
var home_pos: Vector2 = Vector2.ZERO      # where it returns when dropped outside
var target_swap_pos_local: Vector2 = Vector2.ZERO   # local target position
var target_room_for_swap: String = ""     # room to change when puzzle solved

signal object_clicked(obj)

func setup(data: Dictionary) -> void:
	object_type = data.get("tipo", "")
	target_room = data.get("target", "")

	# Set item_name for all except puzzle (puzzle handles its own logic)
	if object_type != "puzzle" and data.has("item"):
		item_name = data.get("item", "")
	
	if object_type == "puzzle":
		var icons_str = data.get("item", "")
		if icons_str != "":
			puzzle_icons = icons_str.split(",")
			for i in range(puzzle_icons.size()):
				puzzle_icons[i] = puzzle_icons[i].strip_edges()
			if puzzle_icons.size() > 0:
				var tex = JSONLoader.get_level_texture(GameState.current_level, puzzle_icons[0])
				if tex:
					sprite.texture = tex
					sprite.centered = true
					_set_collision_from_texture(tex)
				else:
					_set_default_collision()
			else:
				_set_default_collision()
		else:
			_set_default_collision()
		item_name = data.get("icona", "").replace(".png", "")
		puzzle_target = data.get("target", "")
	else:
		if data.has("item"):
			item_name = data.get("item", "").replace(".png", "")
		var texture_path = data.get("icona", "")
		if texture_path:
			var texture = JSONLoader.get_level_texture(GameState.current_level, texture_path)
			if texture:
				sprite.texture = texture
				sprite.centered = true
				_set_collision_from_texture(texture)
			else:
				_set_default_collision()
		else:
			_set_default_collision()
	
	if data.has("pos") and data.pos is Array and data.pos.size() >= 2:
		position = Vector2(data.pos[0], data.pos[1])

	if object_type == "sposta":
		original_home_pos = global_position

	if object_type == "swap":
		home_pos = global_position
		var target_str = data.get("item", "")
		if target_str != "":
			var coords = target_str.split(",")
			if coords.size() == 2:
				target_swap_pos_local = Vector2(coords[0].to_float(), coords[1].to_float())
		target_room_for_swap = data.get("target", "")
	
	if sprite.texture:
		_setup_hover_shader()
	else:
		_set_default_collision()

func _ready() -> void:
	input_pickable = true
	
	# Imposta lo shader per il bordo bianco
	_setup_hover_shader()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _setup_hover_shader() -> void:
	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;
		
		uniform float outline_thickness : hint_range(0, 10) = 1.0;
		uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
		uniform bool show_outline = false;
		uniform vec2 texture_size = vec2(64.0, 64.0);
		
		void fragment() {
			vec4 col = texture(TEXTURE, UV);
			if (!show_outline) {
				COLOR = col;
			} else {
				if (col.a > 0.0) {
					COLOR = col;
				} else {
					vec2 step_uv = 1.0 / texture_size;
					float outline = 0.0;
					for (float dx = -outline_thickness; dx <= outline_thickness; dx += 1.0) {
						for (float dy = -outline_thickness; dy <= outline_thickness; dy += 1.0) {
							if (dx == 0.0 && dy == 0.0) continue;
							vec2 uv2 = UV + vec2(dx, dy) * step_uv;
							if (texture(TEXTURE, uv2).a > 0.0) {
								outline = 1.0;
								break;
							}
						}
						if (outline > 0.0) break;
					}
					COLOR = outline > 0.0 ? outline_color : vec4(0.0);
				}
			}
		}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("show_outline", false)
	material.set_shader_parameter("outline_color", Color.WHITE)
	material.set_shader_parameter("outline_thickness", 1.0)  # 1 pixel
	
	# Imposta la dimensione della texture (deve essere chiamata dopo che la texture è caricata)
	if sprite.texture:
		var tex_size = sprite.texture.get_size()
		material.set_shader_parameter("texture_size", tex_size)
	
	sprite.material = material

func _on_mouse_entered() -> void:
	if not is_being_removed:
		if sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("show_outline", true)

func _on_mouse_exited() -> void:
	if not is_being_removed:
		if sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("show_outline", false)

func _on_input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if is_being_removed:
		return
	
	var now = Time.get_ticks_msec()
	if now - last_click_time < 200:
		return   # ignore if too fast (prevents double events)
	
	var is_clicked = false
	var click_position = Vector2.ZERO
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		is_clicked = true
		click_position = event.global_position
	elif event is InputEventScreenTouch and event.is_pressed():
		is_clicked = true
		click_position = viewport.get_canvas_transform().affine_inverse() * event.position
	
	if is_clicked:
		last_click_time = now
		if object_type != "porta":
			create_puff_effect(click_position)
		object_clicked.emit(self)

func create_puff_effect(position: Vector2) -> void:
	var puff = PUFF_SCENE.instantiate()
	get_tree().current_scene.add_child(puff)
	puff.global_position = position
	puff.rotation = randf() * 2.0 * PI

func animate_collection() -> void:
	is_being_removed = true
	input_pickable = false
	mouse_entered.disconnect(_on_mouse_entered)
	mouse_exited.disconnect(_on_mouse_exited)

# Metodi per puzzle (invariati)
func cycle_puzzle() -> void:
	if puzzle_icons.size() == 0:
		return
	puzzle_index = (puzzle_index + 1) % puzzle_icons.size()
	var icon = puzzle_icons[puzzle_index]
	var tex = JSONLoader.get_level_texture(GameState.current_level, icon)
	if tex:
		sprite.texture = tex

func is_puzzle_correct() -> bool:
	if puzzle_icons.size() == 0:
		return false
	var current_icon = puzzle_icons[puzzle_index]
	return current_icon.get_basename() == item_name.get_basename()

func get_puzzle_target() -> String:
	return puzzle_target

func set_puzzle_index(idx: int) -> void:
	if object_type != "puzzle" or puzzle_icons.is_empty():
		return
	puzzle_index = idx % puzzle_icons.size()
	var tex = JSONLoader.get_level_texture(GameState.current_level, puzzle_icons[puzzle_index])
	if tex:
		sprite.texture = tex

func _set_collision_from_texture(texture: Texture2D) -> void:
	var tex_size = texture.get_size()
	if tex_size.length() == 0:
		_set_default_collision()
		return
	var rect_shape = RectangleShape2D.new()
	rect_shape.extents = tex_size / 2
	$CollisionShape2D.shape = rect_shape

func _set_default_collision() -> void:
	var rect_shape = RectangleShape2D.new()
	rect_shape.extents = Vector2(40, 40)
	$CollisionShape2D.shape = rect_shape
