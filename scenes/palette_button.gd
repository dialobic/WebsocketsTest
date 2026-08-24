extends Button

@export var color_to_bg: Color = Color("70cf9e") # Colore che sostituirà il Teal
@export var color_to_fg: Color = Color("e98b00") # Colore che sostituirà il Giallo

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	GameState.color_bg = color_to_bg
	GameState.color_fg = color_to_fg
		
	# Cambiando scena si applica il colore
	get_tree().change_scene_to_file("res://scenes/LevelSelectScene.tscn")
