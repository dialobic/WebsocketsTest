extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Genera tonalità casuali
	var hue1 = randf_range(0.0, 1.0)
	var hue2 = fmod(hue1 + 0.3 + randf_range(-0.1, 0.1), 1.0)  # complementare con leggera variazione
	
	# Stessa saturazione e luminosità per entrambi i colori
	var saturation = randf_range(0.1, 0.3)  # saturazione
	var value = randf_range(0.81, 0.9)     # luminosità alta
	
	GameState.color_bg = Color.from_hsv(hue1, saturation, value)
	GameState.color_fg = Color.from_hsv(hue2, saturation, value)
	
	# Ricarica la scena per applicare i colori
	get_tree().change_scene_to_file("res://scenes/LevelSelectScene.tscn")
