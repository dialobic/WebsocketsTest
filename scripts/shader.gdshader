shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float tolerance : hint_range(0.0, 0.9) = 0.05;

// Parametro per controllare l'intensità della grana direttamente dal codice
// 0.03 è un valore molto leggero e non fastidioso
uniform float noise_strength : hint_range(0.0, 0.03) = 0.09;

uniform vec4 color_bg : source_color;
uniform vec4 color_fg : source_color;

// Funzione pseudo-random basata sulle coordinate UV
float static_noise(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec4 tex_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec3 rgb = tex_color.rgb;

    // 1. Colori sorgente
    vec3 teal_originale = vec3(0.47, 0.79, 0.77);   // #78c9c4
    vec3 yellow_originale = vec3(1.0, 0.80, 0.0);  // #ffcc00

    vec3 final_rgb;

    // 2. Logica di sostituzione
    if (distance(rgb, teal_originale) < tolerance) {
        final_rgb = color_bg.rgb;
    } 
    else if (distance(rgb, yellow_originale) < tolerance) {
        final_rgb = color_fg.rgb;
    } 
	else {
	        // 3. Effetto seppia dinamico basato su color_bg
	        float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
	        
	        // Estraiamo la direzione del colore di sfondo (normalizzandola per mantenere la "temperatura")
	        // Aggiungiamo un piccolissimo offset (0.001) per evitare divisioni per zero se color_bg fosse nero puro.
	        vec3 tinta_bg = normalize(color_bg.rgb + vec3(0.001));
	        
	        // Bilanciamo l'intensità della tinta. 
	        // Mixiamo il grigio puro con la tinta del background per non avere un effetto troppo violento.
	        // Puoi variare lo 0.5 (es. 0.3 per meno influenza dello sfondo, 0.7 per più influenza)
	        vec3 tinta_seppia = mix(vec3(1.0), tinta_bg * 1.5, 0.5);
	        
	        final_rgb = vec3(gray) * tinta_seppia;
	    }

    // --- AGGIUNTA GRANA STATICA ---
    // Generiamo un valore di rumore tra 0.0 e 1.0 basato sulla posizione del pixel
    float noise = static_noise(SCREEN_UV);
    
    // Applichiamo il rumore: (noise - 0.5) sposta il colore leggermente verso il chiaro o lo scuro
    // Moltiplicandolo per noise_strength lo rendiamo sottile
    final_rgb += (noise - 0.5) * noise_strength;

    COLOR = vec4(final_rgb, tex_color.a);
}