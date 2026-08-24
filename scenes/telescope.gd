extends Node2D

@onready var background: Sprite2D = $Sprite2D

@onready var btn_left: TextureButton = $CanvasLayer/ButtonLeft
@onready var btn_right: TextureButton = $CanvasLayer/ButtonRight
@onready var btn_up: TextureButton = $CanvasLayer/ButtonUp
@onready var btn_down: TextureButton = $CanvasLayer/ButtonDown

# Nodo per l'audio
@onready var click_sound: AudioStreamPlayer = $Sound

const STEP: float = 64.0
const MAX_OFFSET: float = 320.0 # Limite massimo di spostamento dall'origine

# Posizione iniziale dello sfondo (centro dello schermo 512x512)
var initial_position: Vector2

func _ready() -> void:
	initial_position = background.position
	
	# Collegamento dei pulsanti
	btn_left.pressed.connect(func(): move_bg(Vector2(STEP, 0)))
	btn_right.pressed.connect(func(): move_bg(Vector2(-STEP, 0)))
	btn_up.pressed.connect(func(): move_bg(Vector2(0, STEP)))
	btn_down.pressed.connect(func(): move_bg(Vector2(0, -STEP)))
	
	update_buttons_state()

func move_bg(direction: Vector2) -> void:
	click_sound.play()
	# 1. Disabilitiamo tutti i pulsanti durante il movimento
	set_all_buttons_disabled(true)
	
	var target_position: Vector2 = background.position + direction
	
	# 2. Creazione del Tween fluido
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Spostamento in 0.4 secondi (movimento lento e piacevole)
	tween.tween_property(background, "position", target_position, 0.4)
	
	# 3. Al termine del movimento riattiviamo i pulsanti validi
	tween.finished.connect(update_buttons_state)

func update_buttons_state() -> void:
	# Calcoliamo quanto ci siamo spostati rispetto alla posizione iniziale
	var current_offset: Vector2 = background.position - initial_position
	
	# Un pulsante viene disabilitato solo se abbiamo raggiunto o superato il bordo massimo (512px)
	btn_left.disabled = current_offset.x >= MAX_OFFSET
	btn_right.disabled = current_offset.x <= -MAX_OFFSET
	btn_up.disabled = current_offset.y >= MAX_OFFSET
	btn_down.disabled = current_offset.y <= -MAX_OFFSET

func set_all_buttons_disabled(disabled: bool) -> void:
	btn_left.disabled = disabled
	btn_right.disabled = disabled
	btn_up.disabled = disabled
	btn_down.disabled = disabled
