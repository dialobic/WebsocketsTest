extends Sprite2D
class_name NPC

var walk_frames: Array = []
var walk_index: int = 0
var walk_timer: Timer = null
var is_walking: bool = false

func setup_walk(frames: Array) -> void:
	walk_frames = frames
	if walk_frames.size() > 0:
		var tex = JSONLoader.get_level_texture(GameState.current_level, walk_frames[0])
		if tex:
			texture = tex

func start_walking() -> void:
	if walk_frames.size() <= 1:
		return
	is_walking = true
	walk_timer = Timer.new()
	walk_timer.wait_time = 0.13
	walk_timer.timeout.connect(_cycle_walk_frame)
	add_child(walk_timer)
	walk_timer.start()

func stop_walking() -> void:
	is_walking = false
	if walk_timer:
		walk_timer.stop()
		walk_timer.queue_free()
		walk_timer = null

func _cycle_walk_frame() -> void:
	walk_index = (walk_index + 1) % walk_frames.size()
	var tex = JSONLoader.get_level_texture(GameState.current_level, walk_frames[walk_index])
	if tex:
		texture = tex

func _process(delta: float) -> void:
	if is_walking:
		return
	# Original flip logic
	var mouse_pos = get_global_mouse_position()
	flip_h = mouse_pos.x < global_position.x
