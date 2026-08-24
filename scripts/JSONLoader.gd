class_name JSONLoader

static func load_level(level_name: String) -> Dictionary:
	var path = "res://levels/%s/%s.json" % [level_name, level_name]
	
	if not FileAccess.file_exists(path):
		printerr("Level file not found: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		return json.data
	else:
		printerr("JSON Parse Error: ", json.get_error_message())
		return {}

static func get_level_texture(level_name: String, texture_name: String) -> Texture2D:
	# Cerca con nome esatto
	var path = "res://levels/%s/%s" % [level_name, texture_name]
	if ResourceLoader.exists(path):
		return load(path)
	
	# Rimuovi estensione e prova .png, .jpg, .webp
	var base_name = texture_name.get_basename()
	var extensions = ["png", "jpg", "webp"]
	
	for ext in extensions:
		path = "res://levels/%s/%s.%s" % [level_name, base_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	
	# Fallback su assets generali
	path = "res://assets/%s" % texture_name
	if ResourceLoader.exists(path):
		return load(path)
	
	printerr("Texture not found: ", texture_name, " for level: ", level_name)
	return null
