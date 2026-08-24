extends AnimatedSprite2D

# Espone una variabile nell'Inspector per trascinare o selezionare il file della scena (.tscn)
@export_file("*.tscn") var prossima_scena: String

func _ready() -> void:
	# Connette il segnale di fine animazione a questa stessa funzione tramite codice
	# (Puoi anche farlo dall'editor nella scheda "Nodi", ma così è più comodo)
	animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	# Controlliamo prima se è stata effettivamente assegnata una scena nell'Inspector
	if prossima_scena != "":
		# Cambia la scena corrente con quella specificata
		get_tree().change_scene_to_file(prossima_scena)
