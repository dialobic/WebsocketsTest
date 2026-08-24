extends ColorRect

func _ready():
	# Accediamo al materiale del ColorRect
	# Assicurati che nel campo "Material" dell'Inspector ci sia lo ShaderMaterial
	var mat = self.material as ShaderMaterial
	
	if mat:
		# Passiamo i colori dal GameState allo shader
		# NOTA: Il nome tra virgolette deve essere identico al nome dell'uniform nello shader
		mat.set_shader_parameter("color_bg", GameState.color_bg)
		mat.set_shader_parameter("color_fg", GameState.color_fg)
