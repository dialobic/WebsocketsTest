extends TextureButton

signal drag_started(item_key: String, button: TextureButton)

var item_key: String = ""

func _ready():
	button_down.connect(_on_button_down)

func _on_button_down():
	drag_started.emit(item_key, self)
