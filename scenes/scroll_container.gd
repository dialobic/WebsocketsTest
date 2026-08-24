extends ScrollContainer

@export var scroll_speed: float = 500.0
@export var zone_percentage: float = 0.2 # Percentuale dell'area interna al container

func _process(delta: float) -> void:
	# 1. Otteniamo il rettangolo globale dell'inventario e la posizione del mouse
	var global_inv_rect = get_global_rect()
	var mouse_pos = get_global_mouse_position()
	
	# 2. Controlliamo se il mouse è "allineato" orizzontalmente all'inventario
	# (Cioè se la X del mouse è tra l'inizio e la fine della larghezza dell'inventario)
	var is_mouse_aligned_x = mouse_pos.x >= global_inv_rect.position.x and \
							 mouse_pos.x <= global_inv_rect.position.x + global_inv_rect.size.x
	
	if is_mouse_aligned_x:
		# Calcoliamo le soglie basandoci sulla posizione Y globale dell'inventario
		# La zona alta parte dal bordo superiore del container + un piccolo margine interno
		var top_threshold = global_inv_rect.position.y + (global_inv_rect.size.y * zone_percentage)
		
		# La zona bassa parte dal bordo inferiore del container - un piccolo margine interno
		var bottom_threshold = global_inv_rect.position.y + global_inv_rect.size.y * (1.0 - zone_percentage)
		
		# 3. SCORRIMENTO
		# Se il mouse è SOPRA la soglia alta (anche fuori dallo schermo in alto)
		if mouse_pos.y < top_threshold:
			scroll_vertical -= int(scroll_speed * delta)
			
		# Se il mouse è SOTTO la soglia bassa (anche fuori dallo schermo in basso)
		elif mouse_pos.y > bottom_threshold:
			scroll_vertical += int(scroll_speed * delta)
