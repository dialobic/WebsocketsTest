# Puff.gd
extends AnimatedSprite2D

func _ready() -> void:
	# Connetti il segnale per quando l'animazione finisce
	animation_finished.connect(_on_animation_finished)
	
	# Avvia l'animazione
	play("default")

func _on_animation_finished() -> void:
	# Quando l'animazione finisce, distruggi il nodo
	queue_free()
