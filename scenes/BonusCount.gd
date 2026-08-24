extends AnimatedSprite2D

@export var level_name: String = ""
@export var next_level_button: Button = null
@export var unlock_condition: int = 1

func _ready() -> void:
	add_to_group("bonus_counters")
	update_display()

func update_display() -> void:
	if level_name == "":
		return
	
	var bonus_collected = GameState.get_level_progress(level_name)
	bonus_collected = clamp(bonus_collected, 0, 5)
	
	play(str(bonus_collected))
	
	if next_level_button and bonus_collected >= unlock_condition:
		unlock_next_level()

func unlock_next_level() -> void:
	next_level_button.disabled = false
