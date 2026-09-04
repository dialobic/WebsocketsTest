extends Node2D

func _ready():
	# Crea il Tween
	var tween = create_tween().set_parallel(true)  # Esegue i tween in parallelo

	# Anima Sprite2D_sx verso sinistra (-600px)
	tween.tween_property(
		$fog_sx,
		"position:x",
		-400.0,  # Posizione finale
		2.0       # Durata in secondi
	)

	# Anima Sprite2D_dx verso destra (+600px)
	tween.tween_property(
		$fog_dx,
		"position:x",
		1600.0,   # Posizione finale
		2.0       # Durata in secondi
	)

	# Distruggi il nodo (e tutti i suoi figli) al completamento
	await tween.finished
	queue_free()
