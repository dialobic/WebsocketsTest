extends Sprite2D

func appear_at(base_pos: Vector2) -> void:
	# Random offset between -10 and 10 pixels (integer)
	var offset = Vector2(randi_range(-10, 10), randi_range(-10, 10))
	global_position = base_pos + offset
	
	# Start animation (example: fade out and free)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
