extends Control

@onready var share_button = $ShareButton
@onready var time_label = $EndLabel

var experience_name: String = ""
var share_url: String = ""
var time_string: String = "00:00"

func _ready() -> void:
	
	# stop & Mark complete
	CouchGames.gameplay_end()
	CouchGames.gameplay_completed()
	
	# Get experience data
	var exp = await CouchGames.get_experience_data()
	print("Experience data: ", exp)
	
	if exp.success:
		share_url = exp.payload.get("experienceUrl", "")
		# Fallback: construct URL from experienceId if missing
		if share_url == "" and exp.payload.has("experienceId"):
			var exp_id = exp.payload.experienceId
			share_url = "https://couchgames.com/"
		experience_name = exp.payload.get("experienceName", exp.payload.get("title", "this game"))
		share_button.visible = share_url != ""
		if share_button.visible:
			share_button.pressed.connect(_on_share_pressed)
			print("Share button connected")
	else:
		share_button.visible = false
		experience_name = "this game"
	
	# Get session stats
	var stats = await CouchGames.get_session_stats()
	print("Session stats: ", stats)
	
	if stats.success:
		var total_ms = stats.payload.cumulativeGameplayTimeMs
		print("total_ms: ", total_ms)
		# Ensure integer conversion
		var total_seconds = int(total_ms / 1000)
		var minutes = total_seconds / 60
		var seconds = total_seconds % 60
		time_string = "%02d:%02d" % [minutes, seconds]
		print("time_string: ", time_string)
		time_label.text = "We completed %s together in %s." % [experience_name, time_string]
		print("Label text set to: ", time_label.text)
	else:
		time_label.text = "- Experience Completed -"
		print("Stats failed")
	
	# Ensure label is visible
	time_label.visible = true

func _on_share_pressed() -> void:
	print("Share pressed, time_string: ", time_string)
	var share_text = "We completed %s together in %s. Try it at %s." % [experience_name, time_string, share_url]
	DisplayServer.clipboard_set(share_text)
	print("Copied: ", share_text)
	share_button.text = "- Copied! -"
	share_button.disabled = true
	await get_tree().create_timer(2.0).timeout
	share_button.text = "- SHARE -"
	share_button.disabled = false
